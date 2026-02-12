// ══════════════════════════════════════════════════════════════════════
// OSMD Shared Annotation Module
// ══════════════════════════════════════════════════════════════════════
// CANONICAL SOURCE: flutter/assets/js/osmd_annotations.js
// Copied to flutter/web/ by `make sync-annotation-js` (do NOT edit the
// web copy directly — it is generated).
//
// This module provides annotation functionality for OpenSheetMusicDisplay.
// It works in both web (iframe) and native (WebView) contexts.
//
// PLATFORM INTEGRATION:
// The host HTML must set these hooks before using annotation functions:
// - sendToFlutter(eventType, data) - for Flutter communication
// - getMeasureBBox(measureNumber, pageIndex) - for measure positioning
// - findMeasureAtPoint(px, py, pageIndex) - for measure lookup
// ══════════════════════════════════════════════════════════════════════

// ── Global State Variables ────────────────────────────────────────────
var annotationEnabled = false;       // Drawing mode toggle
var isDrawing = false;               // Currently drawing a stroke
var currentStrokePoints = [];        // Points in the current stroke
var annotationCanvases = new Map();  // pageIndex -> canvas element
var storedAnnotations = new Map();   // pageIndex -> [{svgPath, measureNumber, x, y}, ...]
var strokeColor = '#FF0000';
var strokeWidth = 2.5;

// ── Undo/Redo History Stack ───────────────────────────────────────────
var undoStack = [];   // [{pageIndex, annotation}, ...]
var redoStack = [];   // [{pageIndex, annotation}, ...]
var MAX_HISTORY = 100;

// ── Platform-Specific Hooks (MUST be set by host HTML) ───────────────
// These functions provide platform-specific behavior that the host HTML
// must override with its own implementations.

/** Send a message to Flutter (platform-specific implementation required) */
var sendToFlutter = function(eventType, data) {
    console.log('sendToFlutter not configured', eventType, data);
};

/** Get the bounding box of a measure (platform-specific implementation required) */
var getMeasureBBox = function(measureNumber, pageIndex) {
    return null;
};

/** Find which measure is at a given point (platform-specific implementation required) */
var findMeasureAtPoint = function(px, py, pageIndex) {
    return { measureNumber: 1 };
};

// ── Annotation Canvas Management ──────────────────────────────────────

/** Remove all tracked annotation canvases from the DOM and clear the map */
function teardownAnnotationCanvases() {
    for (const [, canvas] of annotationCanvases) {
        canvas.remove();
    }
    annotationCanvases.clear();
}

/** Create or retrieve an annotation canvas for a given OSMD page element */
function getOrCreateAnnotationCanvas(pageDiv, pageIndex) {
    if (annotationCanvases.has(pageIndex)) {
        const existing = annotationCanvases.get(pageIndex);
        // Resize if dimensions changed
        if (existing.width !== pageDiv.clientWidth || existing.height !== pageDiv.clientHeight) {
            existing.width = pageDiv.clientWidth;
            existing.height = pageDiv.clientHeight;
            redrawAnnotations(pageIndex);
        }
        return existing;
    }

    const canvas = document.createElement('canvas');
    canvas.className = 'annotation-canvas';
    canvas.width = pageDiv.clientWidth;
    canvas.height = pageDiv.clientHeight;

    // Set inline styles (CSS class approach doesn't work reliably in Android WebView)
    canvas.style.position = 'absolute';
    canvas.style.top = '0';
    canvas.style.left = '0';
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    canvas.style.zIndex = '10';
    canvas.style.touchAction = 'none';
    canvas.style.pointerEvents = annotationEnabled ? 'auto' : 'none';

    if (annotationEnabled) {
        canvas.classList.add('drawing-mode');
    }

    // Pointer events
    canvas.addEventListener('pointerdown', function(e) { onPointerDown(e, pageIndex); });
    canvas.addEventListener('pointermove', function(e) { onPointerMove(e, pageIndex); });
    canvas.addEventListener('pointerup', function(e) { onPointerUp(e, pageIndex); });
    canvas.addEventListener('pointercancel', function(e) { onPointerUp(e, pageIndex); });

    pageDiv.appendChild(canvas);
    annotationCanvases.set(pageIndex, canvas);
    return canvas;
}

/** Create annotation canvases for all rendered OSMD pages */
function setupAnnotationCanvases() {
    teardownAnnotationCanvases();
    const pages = document.querySelectorAll('div[id^="osmdCanvasPage"]');
    sendToFlutter('debug', { msg: 'setupAnnotationCanvases', pageCount: pages.length, storedSize: storedAnnotations.size });
    pages.forEach(function(pageDiv, index) {
        getOrCreateAnnotationCanvas(pageDiv, index);
    });

    try {
        for (const [pageIndex] of storedAnnotations) {
            sendToFlutter('debug', { msg: 'redrawing page', pageIndex: pageIndex });
            redrawAnnotations(pageIndex);
        }
    } catch (err) {
        sendToFlutter('debug', { msg: 'redraw error', error: err.message, stack: err.stack });
    }
}

// ── Annotation Mode Control ───────────────────────────────────────────

/** Enable or disable annotation drawing mode */
function setAnnotationMode(enabled) {
    annotationEnabled = enabled;
    sendToFlutter('debug', { msg: 'setAnnotationMode', enabled: enabled, canvasCount: annotationCanvases.size });
    for (const [idx, canvas] of annotationCanvases) {
        if (enabled) {
            canvas.classList.add('drawing-mode');
            canvas.style.pointerEvents = 'auto';
            canvas.style.zIndex = '10';
        } else {
            canvas.classList.remove('drawing-mode');
            canvas.style.pointerEvents = 'none';
            canvas.style.zIndex = '10';
        }
        sendToFlutter('debug', { msg: 'canvas mode', idx: idx, inlinePointerEvents: canvas.style.pointerEvents, w: canvas.width, h: canvas.height, classes: canvas.className });
    }

    // When exiting drawing mode, convert all pixel-space annotations
    // to measure-relative coordinates for zoom/reflow resilience.
    if (!enabled) {
        convertAnnotationsToMeasureRelative();
        
        // Send converted annotations back to Flutter for DB update
        const converted = [];
        for (const [pageIndex, annotations] of storedAnnotations) {
            for (const ann of annotations) {
                if (ann.coordSystem === 'measure') {
                    converted.push({
                        pageIndex: pageIndex,
                        measureNumber: ann.measureNumber,
                        svgPath: ann.svgPath,
                        x: ann.x,
                        y: ann.y,
                        coordSystem: 'measure'
                    });
                }
            }
        }
        if (converted.length > 0) {
            sendToFlutter('annotationsConverted', { annotations: converted });
        }
    }

    sendToFlutter('annotationModeChanged', { enabled: enabled });
}

/** Set stroke style for drawing */
function setAnnotationStyle(color, width) {
    if (color) strokeColor = color;
    if (width) strokeWidth = width;
}

// ── Pointer Event Handlers ────────────────────────────────────────────

function onPointerDown(e, pageIndex) {
    sendToFlutter('debug', { msg: 'pointerDown', pageIndex: pageIndex, enabled: annotationEnabled, clientX: e.clientX, clientY: e.clientY });
    if (!annotationEnabled) return;
    e.preventDefault();
    isDrawing = true;

    const canvas = annotationCanvases.get(pageIndex);
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    sendToFlutter('debug', { msg: 'drawStart', x: Math.round(x), y: Math.round(y), canvasW: canvas.width, canvasH: canvas.height, color: strokeColor, width: strokeWidth });

    currentStrokePoints = [{ x: x, y: y }];

    // Start drawing preview
    const ctx = canvas.getContext('2d');
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.strokeStyle = strokeColor;
    ctx.lineWidth = strokeWidth;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
}

function onPointerMove(e, pageIndex) {
    if (!isDrawing || !annotationEnabled) return;
    e.preventDefault();

    const canvas = annotationCanvases.get(pageIndex);
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    currentStrokePoints.push({ x: x, y: y });

    // Draw line segment preview
    const ctx = canvas.getContext('2d');
    ctx.lineTo(x, y);
    ctx.stroke();
}

function onPointerUp(e, pageIndex) {
    sendToFlutter('debug', { msg: 'pointerUp', pageIndex: pageIndex, isDrawing: isDrawing, points: currentStrokePoints.length });
    if (!isDrawing) return;
    e.preventDefault();
    isDrawing = false;

    // Need at least 2 points for a stroke
    if (currentStrokePoints.length < 2) {
        currentStrokePoints = [];
        return;
    }

    const canvas = annotationCanvases.get(pageIndex);
    const midPoint = currentStrokePoints[Math.floor(currentStrokePoints.length / 2)];
    const measureInfo = findMeasureAtPoint(midPoint.x, midPoint.y, pageIndex);

    // Store the raw pixel SVG path and the canvas size at draw time.
    // On redraw at a different size, we scale proportionally.
    const svgPath = pointsToSvgPath(currentStrokePoints);

    const annotation = {
        svgPath: svgPath,
        measureNumber: measureInfo.measureNumber,
        x: midPoint.x / canvas.width,
        y: midPoint.y / canvas.height,
        color: strokeColor,
        width: strokeWidth,
        // Starts as pixel coords; converted to measure-relative on exit drawing mode
        coordSystem: 'pixel',
        origWidth: canvas.width,
        origHeight: canvas.height
    };

    if (!storedAnnotations.has(pageIndex)) {
        storedAnnotations.set(pageIndex, []);
    }
    storedAnnotations.get(pageIndex).push(annotation);

    pushToUndoStack(pageIndex, annotation);

    sendToFlutter('annotationAdded', {
        pageIndex: pageIndex,
        measureNumber: measureInfo.measureNumber,
        svgPath: svgPath,
        x: midPoint.x,
        y: midPoint.y,
        color: strokeColor,
        width: strokeWidth
    });

    currentStrokePoints = [];
    redrawAnnotations(pageIndex);
}

// ── SVG Path Generation ───────────────────────────────────────────────

/** Convert an array of {x, y} points to an SVG path string */
function pointsToSvgPath(points) {
    if (points.length === 0) return '';
    var path = 'M ' + points[0].x.toFixed(1) + ' ' + points[0].y.toFixed(1);
    for (var i = 1; i < points.length; i++) {
        path += ' L ' + points[i].x.toFixed(1) + ' ' + points[i].y.toFixed(1);
    }
    return path;
}

/** Like pointsToSvgPath but with higher decimal precision for normalized coords */
function pointsToSvgPathPrecise(points) {
    if (points.length === 0) return '';
    var path = 'M ' + points[0].x.toFixed(4) + ' ' + points[0].y.toFixed(4);
    for (var i = 1; i < points.length; i++) {
        path += ' L ' + points[i].x.toFixed(4) + ' ' + points[i].y.toFixed(4);
    }
    return path;
}

/** Parse an SVG path string back to an array of {x, y} points */
function svgPathToPoints(svgPath) {
    const points = [];
    const commands = svgPath.match(/[ML]\s*-?[\d.]+\s+-?[\d.]+/g);
    if (!commands) return points;
    for (var i = 0; i < commands.length; i++) {
        const cmd = commands[i];
        const nums = cmd.match(/-?[\d.]+/g);
        if (nums && nums.length >= 2) {
            points.push({ x: parseFloat(nums[0]), y: parseFloat(nums[1]) });
        }
    }
    return points;
}

// ── Coordinate Conversion ─────────────────────────────────────────────

/**
 * Convert all annotations still in 'pixel' coord system to 'measure' coords.
 * Called once when exiting drawing mode.
 */
function convertAnnotationsToMeasureRelative() {
    for (const [pageIndex, annotations] of storedAnnotations) {
        for (var i = 0; i < annotations.length; i++) {
            const ann = annotations[i];
            if (ann.coordSystem === 'measure') continue; // already converted

            const mBBox = getMeasureBBox(ann.measureNumber, pageIndex);
            if (!mBBox || mBBox.w <= 0 || mBBox.h <= 0) continue; // can't convert, leave as pixel

            // Parse the pixel-space SVG path
            const pixelPoints = svgPathToPoints(ann.svgPath);
            if (pixelPoints.length < 2) continue;

            // Convert each point to measure-relative (0-1 within measure bbox)
            const relPoints = pixelPoints.map(function(p) {
                return {
                    x: (p.x - mBBox.x) / mBBox.w,
                    y: (p.y - mBBox.y) / mBBox.h
                };
            });

            // Use higher precision for normalized coords
            ann.svgPath = pointsToSvgPathPrecise(relPoints);
            ann.coordSystem = 'measure';

            // Also update the midpoint x/y to measure-relative
            const mid = relPoints[Math.floor(relPoints.length / 2)];
            ann.x = mid.x;
            ann.y = mid.y;
        }
    }
}

// ── Annotation Rendering ──────────────────────────────────────────────

/** Redraw all stored annotations for a given page */
function redrawAnnotations(pageIndex) {
    const canvas = annotationCanvases.get(pageIndex);
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    const annotations = storedAnnotations.get(pageIndex);
    if (!annotations) return;

    sendToFlutter('debug', { msg: 'redraw', pageIndex: pageIndex, count: annotations.length, canvasW: canvas.width, canvasH: canvas.height });

    for (var i = 0; i < annotations.length; i++) {
        const ann = annotations[i];

        if (ann.type === 'structured' && ann.kind && STRUCTURED_SYMBOLS[ann.kind]) {
            const px = ann.x * canvas.width;
            const py = ann.y * canvas.height;
            STRUCTURED_SYMBOLS[ann.kind].render(ctx, px, py, ann.data || {});
        } else if (ann.svgPath) {
            if (ann.coordSystem === 'measure') {
                const mBBox = getMeasureBBox(ann.measureNumber, pageIndex);
                sendToFlutter('debug', { msg: 'redraw-measure', i: i, measure: ann.measureNumber, hasBBox: !!mBBox, bbox: mBBox });
                if (mBBox) {
                    drawSvgPathMeasureRelative(ctx, ann.svgPath, ann.color || strokeColor, ann.width || strokeWidth, mBBox);
                }
            } else {
                const scaleX = ann.origWidth ? canvas.width / ann.origWidth : 1;
                const scaleY = ann.origHeight ? canvas.height / ann.origHeight : 1;
                sendToFlutter('debug', { msg: 'redraw-pixel', i: i, coordSystem: ann.coordSystem, origW: ann.origWidth, origH: ann.origHeight, scaleX: scaleX, scaleY: scaleY });
                drawSvgPathScaled(ctx, ann.svgPath, ann.color || strokeColor, ann.width || strokeWidth, scaleX, scaleY);
            }
        }
    }
}

/**
 * Draw an SVG path with proportional scaling.
 * Points in the path are in original pixel coordinates;
 * scaleX/scaleY transform them to current canvas size.
 */
function drawSvgPathScaled(ctx, svgPath, color, width, scaleX, scaleY) {
    const points = svgPathToPoints(svgPath);
    if (points.length < 2) return;

    ctx.beginPath();
    ctx.moveTo(points[0].x * scaleX, points[0].y * scaleY);
    for (var i = 1; i < points.length; i++) {
        ctx.lineTo(points[i].x * scaleX, points[i].y * scaleY);
    }
    ctx.strokeStyle = color;
    ctx.lineWidth = width;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.stroke();
}

/**
 * Draw an SVG path stored in measure-relative coordinates.
 * Points are offsets within the measure bbox (0-1 range).
 * Scaled to the measure's current pixel position.
 */
function drawSvgPathMeasureRelative(ctx, svgPath, color, width, mBBox) {
    const points = svgPathToPoints(svgPath);
    if (points.length < 2) return;

    ctx.beginPath();
    ctx.moveTo(mBBox.x + points[0].x * mBBox.w, mBBox.y + points[0].y * mBBox.h);
    for (var i = 1; i < points.length; i++) {
        ctx.lineTo(mBBox.x + points[i].x * mBBox.w, mBBox.y + points[i].y * mBBox.h);
    }
    ctx.strokeStyle = color;
    ctx.lineWidth = width;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.stroke();
}

// ── Annotation CRUD Operations ────────────────────────────────────────

/** Load previously saved annotations into the renderer */
function loadAnnotations(annotations) {
    storedAnnotations.clear();
    for (var i = 0; i < annotations.length; i++) {
        const ann = annotations[i];
        const pi = ann.pageIndex || 0;
        if (!storedAnnotations.has(pi)) {
            storedAnnotations.set(pi, []);
        }
        storedAnnotations.get(pi).push(ann);
    }

    // Convert any pixel-space annotations to measure-relative for zoom resilience
    convertAnnotationsToMeasureRelative();

    for (const [pi] of storedAnnotations) {
        redrawAnnotations(pi);
    }
}

/** Clear annotations for a specific page, or all pages if pageIndex is null */
function clearAnnotations(pageIndex) {
    if (pageIndex !== undefined && pageIndex !== null) {
        storedAnnotations.delete(pageIndex);
        redrawAnnotations(pageIndex);
    } else {
        storedAnnotations.clear();
        for (const [pi] of annotationCanvases) {
            redrawAnnotations(pi);
        }
    }
    sendToFlutter('annotationsCleared', { pageIndex: pageIndex !== null && pageIndex !== undefined ? pageIndex : -1 });
}

/** Remove the last drawn annotation from a specific page */
function removeLastAnnotation(pageIndex) {
    const annotations = storedAnnotations.get(pageIndex);
    if (annotations && annotations.length > 0) {
        const removed = annotations.pop();
        redrawAnnotations(pageIndex);
        sendToFlutter('annotationRemoved', {
            pageIndex: pageIndex,
            measureNumber: removed.measureNumber,
            remaining: annotations.length
        });
    }
}

// ── Structured Annotation Symbols ─────────────────────────────────────

/** Symbol definitions for structured annotations */
var STRUCTURED_SYMBOLS = {
    fingerNumber: {
        render: function(ctx, x, y, data) {
            const num = data.value || '1';
            ctx.font = 'bold 16px serif';
            ctx.fillStyle = data.color || '#0066CC';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(num, x, y);
        }
    },
    dynamicMark: {
        render: function(ctx, x, y, data) {
            const mark = data.value || 'mf';
            ctx.font = 'italic bold 14px serif';
            ctx.fillStyle = data.color || '#CC0000';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(mark, x, y);
        }
    },
    bowing: {
        render: function(ctx, x, y, data) {
            const type = data.value || 'down';
            ctx.strokeStyle = data.color || '#333333';
            ctx.lineWidth = 2;
            ctx.beginPath();
            if (type === 'down') {
                ctx.moveTo(x - 8, y - 10);
                ctx.lineTo(x - 8, y + 2);
                ctx.lineTo(x + 8, y + 2);
                ctx.lineTo(x + 8, y - 10);
            } else {
                ctx.moveTo(x - 8, y + 6);
                ctx.lineTo(x, y - 10);
                ctx.lineTo(x + 8, y + 6);
            }
            ctx.stroke();
        }
    },
    articulation: {
        render: function(ctx, x, y, data) {
            const type = data.value || 'staccato';
            ctx.fillStyle = data.color || '#333333';
            ctx.strokeStyle = data.color || '#333333';
            ctx.lineWidth = 2;
            switch (type) {
                case 'staccato':
                    ctx.beginPath();
                    ctx.arc(x, y, 3, 0, Math.PI * 2);
                    ctx.fill();
                    break;
                case 'accent':
                    ctx.beginPath();
                    ctx.moveTo(x - 8, y - 4);
                    ctx.lineTo(x + 8, y);
                    ctx.lineTo(x - 8, y + 4);
                    ctx.stroke();
                    break;
                case 'tenuto':
                    ctx.beginPath();
                    ctx.moveTo(x - 8, y);
                    ctx.lineTo(x + 8, y);
                    ctx.stroke();
                    break;
                case 'fermata':
                    ctx.beginPath();
                    ctx.arc(x, y - 2, 8, Math.PI, 0);
                    ctx.stroke();
                    ctx.beginPath();
                    ctx.arc(x, y - 2, 2, 0, Math.PI * 2);
                    ctx.fill();
                    break;
                default:
                    ctx.beginPath();
                    ctx.arc(x, y, 3, 0, Math.PI * 2);
                    ctx.fill();
            }
        }
    }
};

/** Add a structured annotation symbol to a page */
function addStructuredAnnotation(pageIndex, kind, measureNumber, normX, normY, data) {
    const canvas = annotationCanvases.get(pageIndex);
    if (!canvas) return;

    const annotation = {
        type: 'structured',
        kind: kind,
        measureNumber: measureNumber,
        x: normX,
        y: normY,
        data: data || {},
        color: (data && data.color) || strokeColor
    };

    if (!storedAnnotations.has(pageIndex)) {
        storedAnnotations.set(pageIndex, []);
    }
    storedAnnotations.get(pageIndex).push(annotation);

    pushToUndoStack(pageIndex, annotation);
    redrawAnnotations(pageIndex);

    sendToFlutter('annotationAdded', {
        pageIndex: pageIndex,
        measureNumber: measureNumber,
        svgPath: '',
        x: normX,
        y: normY,
        color: annotation.color,
        width: 0,
        structured: true,
        kind: kind,
        data: data
    });
}

// ── Undo/Redo Functions ───────────────────────────────────────────────

function pushToUndoStack(pageIndex, annotation) {
    undoStack.push({ pageIndex: pageIndex, annotation: annotation });
    if (undoStack.length > MAX_HISTORY) {
        undoStack.shift();
    }
    redoStack = [];
    notifyHistoryState();
}

function undoAnnotation() {
    if (undoStack.length === 0) return;

    const entry = undoStack.pop();
    const pageIndex = entry.pageIndex;
    const annotation = entry.annotation;

    const annotations = storedAnnotations.get(pageIndex);
    if (annotations) {
        const idx = annotations.indexOf(annotation);
        if (idx !== -1) {
            annotations.splice(idx, 1);
        } else if (annotations.length > 0) {
            annotations.pop();
        }
        redrawAnnotations(pageIndex);
    }

    redoStack.push(entry);
    notifyHistoryState();
}

function redoAnnotation() {
    if (redoStack.length === 0) return;

    const entry = redoStack.pop();
    const pageIndex = entry.pageIndex;
    const annotation = entry.annotation;

    if (!storedAnnotations.has(pageIndex)) {
        storedAnnotations.set(pageIndex, []);
    }
    storedAnnotations.get(pageIndex).push(annotation);
    redrawAnnotations(pageIndex);

    undoStack.push(entry);
    notifyHistoryState();
}

function notifyHistoryState() {
    sendToFlutter('historyChanged', {
        canUndo: undoStack.length > 0,
        canRedo: redoStack.length > 0,
        undoCount: undoStack.length,
        redoCount: redoStack.length
    });
}
