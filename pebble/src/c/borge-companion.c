#include <pebble.h>

// App state enum
typedef enum {
  APP_STATE_LOADING,
  APP_STATE_SONG_LIST,
  APP_STATE_SONG_VIEW
} AppState;

// AppMessage keys - must match Flutter side
typedef enum {
  KEY_COMMAND = 0,
  KEY_SONG_ID = 1,
  KEY_SONG_NAME = 2,
  KEY_PAGE_NUM = 3,
  KEY_PAGE_COUNT = 4,
  KEY_SONG_COUNT = 5,
  KEY_SONG_INDEX = 6
} AppMessageKey;

// Command types
typedef enum {
  CMD_GET_LIST = 1,
  CMD_SELECT_SONG = 2,
  CMD_NEXT_PAGE = 3,
  CMD_PREV_PAGE = 4,
  CMD_NEXT_SONG = 5,
  CMD_PREV_SONG = 6,
  CMD_ACK = 100,
  CMD_LIST_RESP = 101,
  CMD_PAGE_LOADED = 102,
  CMD_ERROR = 255
} CommandType;

// Global state
static Window *s_main_window;
static TextLayer *s_title_layer;
static TextLayer *s_info_layer;
static TextLayer *s_status_layer;

static AppState s_app_state = APP_STATE_LOADING;
static char s_current_song_id[16] = "";
static char s_current_song_name[64] = "Loading...";
static int s_current_page = 0;
static int s_total_pages = 0;
static int s_current_song_index = 0;
static int s_total_songs = 0;

static char s_title_buffer[64];
static char s_info_buffer[32];

// Vibration patterns
static void vibe_success(void) {
  vibes_short_pulse();
}

static void vibe_error(void) {
  vibes_long_pulse();
}

static void vibe_confirm(void) {
  static const uint32_t segments[] = {100, 100, 100};
  VibePattern pattern = {
    .durations = segments,
    .num_segments = ARRAY_LENGTH(segments)
  };
  vibes_enqueue_custom_pattern(pattern);
}

static void vibe_page_turn(void) {
  static const uint32_t segments[] = {50};
  VibePattern pattern = {
    .durations = segments,
    .num_segments = ARRAY_LENGTH(segments)
  };
  vibes_enqueue_custom_pattern(pattern);
}

// UI update functions
static void update_ui(void) {
  switch (s_app_state) {
    case APP_STATE_LOADING:
      text_layer_set_text(s_title_layer, "Borge");
      text_layer_set_text(s_info_layer, "Connecting...");
      text_layer_set_text(s_status_layer, "");
      break;

    case APP_STATE_SONG_LIST:
      snprintf(s_title_buffer, sizeof(s_title_buffer), "%s", s_current_song_name);
      text_layer_set_text(s_title_layer, s_title_buffer);

      snprintf(s_info_buffer, sizeof(s_info_buffer), "Song %d of %d",
               s_current_song_index + 1, s_total_songs);
      text_layer_set_text(s_info_layer, s_info_buffer);

      text_layer_set_text(s_status_layer, "SELECT to open");
      break;

    case APP_STATE_SONG_VIEW:
      snprintf(s_title_buffer, sizeof(s_title_buffer), "%s", s_current_song_name);
      text_layer_set_text(s_title_layer, s_title_buffer);

      snprintf(s_info_buffer, sizeof(s_info_buffer), "Page %d of %d",
               s_current_page, s_total_pages);
      text_layer_set_text(s_info_layer, s_info_buffer);

      text_layer_set_text(s_status_layer, "BACK for list");
      break;
  }
}

// Send command to phone
static void send_command(CommandType cmd) {
  DictionaryIterator *iter;
  AppMessageResult result = app_message_outbox_begin(&iter);

  if (result != APP_MSG_OK) {
    APP_LOG(APP_LOG_LEVEL_ERROR, "Failed to begin outbox: %d", (int)result);
    return;
  }

  dict_write_uint8(iter, KEY_COMMAND, cmd);

  if (cmd == CMD_SELECT_SONG && strlen(s_current_song_id) > 0) {
    dict_write_cstring(iter, KEY_SONG_ID, s_current_song_id);
  }

  result = app_message_outbox_send();
  if (result != APP_MSG_OK) {
    APP_LOG(APP_LOG_LEVEL_ERROR, "Failed to send message: %d", (int)result);
  }
}

// AppMessage callbacks
static void inbox_received_callback(DictionaryIterator *iterator, void *context) {
  Tuple *cmd_tuple = dict_find(iterator, KEY_COMMAND);
  if (!cmd_tuple) return;

  CommandType cmd = cmd_tuple->value->uint8;

  switch (cmd) {
    case CMD_LIST_RESP: {
      Tuple *song_id = dict_find(iterator, KEY_SONG_ID);
      Tuple *song_name = dict_find(iterator, KEY_SONG_NAME);
      Tuple *song_count = dict_find(iterator, KEY_SONG_COUNT);
      Tuple *song_index = dict_find(iterator, KEY_SONG_INDEX);
      Tuple *page_count = dict_find(iterator, KEY_PAGE_COUNT);

      if (song_id) {
        strncpy(s_current_song_id, song_id->value->cstring, sizeof(s_current_song_id) - 1);
      }
      if (song_name) {
        strncpy(s_current_song_name, song_name->value->cstring, sizeof(s_current_song_name) - 1);
      }
      if (song_count) {
        s_total_songs = song_count->value->int32;
      }
      if (song_index) {
        s_current_song_index = song_index->value->int32;
      }
      if (page_count) {
        s_total_pages = page_count->value->int32;
      }

      s_app_state = APP_STATE_SONG_LIST;
      update_ui();
      vibe_success();
      break;
    }

    case CMD_PAGE_LOADED: {
      Tuple *page_num = dict_find(iterator, KEY_PAGE_NUM);
      Tuple *page_count = dict_find(iterator, KEY_PAGE_COUNT);

      if (page_num) {
        s_current_page = page_num->value->int32;
      }
      if (page_count) {
        s_total_pages = page_count->value->int32;
      }

      s_app_state = APP_STATE_SONG_VIEW;
      update_ui();
      vibe_page_turn();
      break;
    }

    case CMD_ACK:
      vibe_success();
      update_ui();
      break;

    case CMD_ERROR:
      vibe_error();
      break;

    default:
      break;
  }
}

static void inbox_dropped_callback(AppMessageResult reason, void *context) {
  APP_LOG(APP_LOG_LEVEL_ERROR, "Message dropped: %d", (int)reason);
}

static void outbox_failed_callback(DictionaryIterator *iterator, AppMessageResult reason, void *context) {
  APP_LOG(APP_LOG_LEVEL_ERROR, "Outbox send failed: %d", (int)reason);
  vibe_error();
}

static void outbox_sent_callback(DictionaryIterator *iterator, void *context) {
  APP_LOG(APP_LOG_LEVEL_DEBUG, "Outbox send success");
}

// Button handlers
static void up_click_handler(ClickRecognizerRef recognizer, void *context) {
  switch (s_app_state) {
    case APP_STATE_SONG_LIST:
      send_command(CMD_PREV_SONG);
      break;
    case APP_STATE_SONG_VIEW:
      send_command(CMD_PREV_PAGE);
      break;
    default:
      break;
  }
}

static void down_click_handler(ClickRecognizerRef recognizer, void *context) {
  switch (s_app_state) {
    case APP_STATE_SONG_LIST:
      send_command(CMD_NEXT_SONG);
      break;
    case APP_STATE_SONG_VIEW:
      send_command(CMD_NEXT_PAGE);
      break;
    default:
      break;
  }
}

static void select_click_handler(ClickRecognizerRef recognizer, void *context) {
  switch (s_app_state) {
    case APP_STATE_LOADING:
      send_command(CMD_GET_LIST);
      break;
    case APP_STATE_SONG_LIST:
      send_command(CMD_SELECT_SONG);
      vibe_confirm();
      break;
    case APP_STATE_SONG_VIEW:
      break;
    default:
      break;
  }
}

static void back_click_handler(ClickRecognizerRef recognizer, void *context) {
  switch (s_app_state) {
    case APP_STATE_SONG_VIEW:
      s_app_state = APP_STATE_SONG_LIST;
      s_current_page = 0;
      update_ui();
      vibe_success();
      break;
    default:
      window_stack_pop(true);
      break;
  }
}

static void click_config_provider(void *context) {
  window_single_click_subscribe(BUTTON_ID_UP, up_click_handler);
  window_single_click_subscribe(BUTTON_ID_DOWN, down_click_handler);
  window_single_click_subscribe(BUTTON_ID_SELECT, select_click_handler);
  window_single_click_subscribe(BUTTON_ID_BACK, back_click_handler);
}

// Window handlers
static void main_window_load(Window *window) {
  Layer *window_layer = window_get_root_layer(window);
  GRect bounds = layer_get_bounds(window_layer);

  // Title layer - top
  s_title_layer = text_layer_create(GRect(5, 20, bounds.size.w - 10, 50));
  text_layer_set_background_color(s_title_layer, GColorClear);
  text_layer_set_text_color(s_title_layer, GColorBlack);
  text_layer_set_font(s_title_layer, fonts_get_system_font(FONT_KEY_GOTHIC_24_BOLD));
  text_layer_set_text_alignment(s_title_layer, GTextAlignmentCenter);
  text_layer_set_overflow_mode(s_title_layer, GTextOverflowModeWordWrap);
  layer_add_child(window_layer, text_layer_get_layer(s_title_layer));

  // Info layer - middle
  s_info_layer = text_layer_create(GRect(5, 80, bounds.size.w - 10, 30));
  text_layer_set_background_color(s_info_layer, GColorClear);
  text_layer_set_text_color(s_info_layer, GColorDarkGray);
  text_layer_set_font(s_info_layer, fonts_get_system_font(FONT_KEY_GOTHIC_18));
  text_layer_set_text_alignment(s_info_layer, GTextAlignmentCenter);
  layer_add_child(window_layer, text_layer_get_layer(s_info_layer));

  // Status layer - bottom
  s_status_layer = text_layer_create(GRect(5, bounds.size.h - 30, bounds.size.w - 10, 25));
  text_layer_set_background_color(s_status_layer, GColorClear);
  text_layer_set_text_color(s_status_layer, GColorDarkGray);
  text_layer_set_font(s_status_layer, fonts_get_system_font(FONT_KEY_GOTHIC_14));
  text_layer_set_text_alignment(s_status_layer, GTextAlignmentCenter);
  layer_add_child(window_layer, text_layer_get_layer(s_status_layer));

  update_ui();
}

static void main_window_unload(Window *window) {
  text_layer_destroy(s_title_layer);
  text_layer_destroy(s_info_layer);
  text_layer_destroy(s_status_layer);
}

// App lifecycle
static void init(void) {
  // Register AppMessage handlers
  app_message_register_inbox_received(inbox_received_callback);
  app_message_register_inbox_dropped(inbox_dropped_callback);
  app_message_register_outbox_failed(outbox_failed_callback);
  app_message_register_outbox_sent(outbox_sent_callback);

  // Open AppMessage
  const int inbox_size = 256;
  const int outbox_size = 256;
  app_message_open(inbox_size, outbox_size);

  // Create main window
  s_main_window = window_create();
  window_set_click_config_provider(s_main_window, click_config_provider);
  window_set_window_handlers(s_main_window, (WindowHandlers) {
    .load = main_window_load,
    .unload = main_window_unload
  });

  window_stack_push(s_main_window, true);

  // Request initial song list
  send_command(CMD_GET_LIST);
}

static void deinit(void) {
  window_destroy(s_main_window);
}

int main(void) {
  init();
  app_event_loop();
  deinit();
}
