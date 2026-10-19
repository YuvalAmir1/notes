/* my-keyboard.c --- The key a character came from, for Emacs

   With a layout of another script on, such as Hebrew, (my-keyboard-latin
   CHAR) is what the same key types in the Latin layout, the one commands
   are typed with: Dvorak's, Colemak's or QWERTY's, whichever it is. With a
   Latin layout on it's nil. The system says which layout is on and what
   each key types in each, so nothing is set up for a layout:

   - pgtk (Wayland): GTK, which Emacs takes its keys from, gives each key's
     layout and physical key.
   - X11: the keyboard extension gives the layout in use and the keymap.
   - Windows: the layout in use, and what a key types in any layout.
   - macOS: the input source in use, and the Latin one it pairs with.

   (my-keyboard-start WINDOW-SYSTEM DISPLAY) starts it for a frame;
   (my-keyboard-layout) says what it sees, for checking.  */

#include <emacs-module.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

int plugin_is_GPL_compatible;

static emacs_value
lisp_nil (emacs_env *env)
{
  return env->intern (env, "nil");
}

/* At least half the letter keys type a-z.  */
#define LATIN(count) ((count) >= 13)

#if defined _WIN32

#include <windows.h>

/* Scan codes of the keys that type characters (with the ISO key and the
   Japanese keyboard's Yen and Ro), and of the letter keys.  */
static const UINT keys[] = {
  0x29, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C,
  0x0D, 0x7D, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19,
  0x1A, 0x1B, 0x2B, 0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26,
  0x27, 0x28, 0x56, 0x2C, 0x2D, 0x2E, 0x2F, 0x30, 0x31, 0x32, 0x33, 0x34,
  0x35, 0x73,
};
static const UINT letters[] = {
  0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1E, 0x1F,
  0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x2C, 0x2D, 0x2E, 0x2F, 0x30,
  0x31, 0x32,
};

static uint32_t
key_char (HKL layout, UINT key, int shift)
{
  BYTE state[256] = { 0 };
  WCHAR out[4];
  UINT virtual_key = MapVirtualKeyExW (key, MAPVK_VSC_TO_VK, layout);
  if (!virtual_key)
    return 0;
  if (shift)
    state[VK_SHIFT] = 0x80;
  /* 4: leave the keyboard's state, dead keys included, as it is.  */
  return ToUnicodeEx (virtual_key, key, state, out, 4, 4, layout) == 1 ? out[0] : 0;
}

static int
latin_p (HKL layout)
{
  int count = 0;
  for (size_t i = 0; i < sizeof letters / sizeof *letters; i++)
    {
      uint32_t c = key_char (layout, letters[i], 0);
      count += c >= 'a' && c <= 'z';
    }
  return LATIN (count);
}

static HKL last_latin;

static HKL
current (void)
{
  HWND window = GetForegroundWindow ();
  return GetKeyboardLayout (window ? GetWindowThreadProcessId (window, NULL) : 0);
}

/* The Latin layout last typed in, else the first.  */
static HKL
latin_layout (void)
{
  HKL layouts[32];
  int n = GetKeyboardLayoutList (32, layouts);
  for (int i = 0; i < n; i++)
    if (layouts[i] == last_latin)
      return last_latin;
  for (int i = 0; i < n; i++)
    if (latin_p (layouts[i]))
      return layouts[i];
  return NULL;
}

static uint32_t
latin (uint32_t c)
{
  HKL layout = current (), to;
  if (latin_p (layout))
    {
      last_latin = layout;
      return 0;
    }
  if (!(to = latin_layout ()))
    return 0;
  for (int shift = 0; shift < 2; shift++)
    for (size_t i = 0; i < sizeof keys / sizeof *keys; i++)
      if (key_char (layout, keys[i], shift) == c)
        {
          uint32_t result = key_char (to, keys[i], shift);
          return result == c ? 0 : result;
        }
  return 0;
}

static int
start (const char *window_system, const char *display)
{
  return 1;
}

static void
describe (char *out, size_t size)
{
  HKL layout = current (), to = latin_layout ();
  snprintf (out, size, "(%llu %llu %s)", (unsigned long long) (uintptr_t) layout,
            (unsigned long long) (uintptr_t) to, latin_p (layout) ? "t" : "nil");
}

#elif defined __APPLE__

#include <Carbon/Carbon.h>

/* The keys that type characters have the virtual key codes 0x00 to 0x32,
   but for Return, Tab and Space, and the Japanese keyboard's Yen and Ro
   0x5D and 0x5E. macOS says which layouts are Latin.  */
static const UInt16 keys[] = {
  0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B,
  0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
  0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23,
  0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F, 0x32,
  0x5D, 0x5E,
};

static uint32_t
key_char (TISInputSourceRef source, UInt16 key, UInt32 modifiers)
{
  CFDataRef data = TISGetInputSourceProperty (source, kTISPropertyUnicodeKeyLayoutData);
  UInt32 dead = 0;
  UniChar out[4];
  UniCharCount n = 0;
  if (!data
      || UCKeyTranslate ((const UCKeyboardLayout *) CFDataGetBytePtr (data), key,
                         kUCKeyActionDown, (modifiers >> 8) & 0xFF, LMGetKbdType (),
                         kUCKeyTranslateNoDeadKeysMask, &dead, 4, &n, out) != noErr
      || n != 1)
    return 0;
  return out[0];
}

static int
latin_p (TISInputSourceRef source)
{
  CFBooleanRef ascii = TISGetInputSourceProperty (source, kTISPropertyInputSourceIsASCIICapable);
  return ascii && CFBooleanGetValue (ascii);
}

static uint32_t
latin (uint32_t c)
{
  static const UInt32 modifiers[] = { 0, shiftKey, optionKey, shiftKey | optionKey };
  TISInputSourceRef layout = TISCopyCurrentKeyboardLayoutInputSource ();
  TISInputSourceRef to = TISCopyCurrentASCIICapableKeyboardLayoutInputSource ();
  uint32_t result = 0;
  int found = 0;
  if (layout && to && !latin_p (layout))
    for (int m = 0; m < 4 && !found; m++)
      for (size_t i = 0; i < sizeof keys / sizeof *keys && !found; i++)
        if (key_char (layout, keys[i], modifiers[m]) == c)
          {
            found = 1;
            result = key_char (to, keys[i], modifiers[m]);
          }
  if (layout)
    CFRelease (layout);
  if (to)
    CFRelease (to);
  return result == c ? 0 : result;
}

static int
start (const char *window_system, const char *display)
{
  return 1;
}

static void
id (TISInputSourceRef source, char *out, size_t size)
{
  CFStringRef name = source ? TISGetInputSourceProperty (source, kTISPropertyInputSourceID) : NULL;
  if (!name || !CFStringGetCString (name, out, size, kCFStringEncodingUTF8))
    snprintf (out, size, "?");
}

static void
describe (char *out, size_t size)
{
  char from[128], to[128];
  TISInputSourceRef layout = TISCopyCurrentKeyboardLayoutInputSource ();
  TISInputSourceRef ascii = TISCopyCurrentASCIICapableKeyboardLayoutInputSource ();
  id (layout, from, sizeof from);
  id (ascii, to, sizeof to);
  snprintf (out, size, "(\"%s\" \"%s\" %s)", from, to,
            layout && latin_p (layout) ? "t" : "nil");
  if (layout)
    CFRelease (layout);
  if (ascii)
    CFRelease (ascii);
}

#else

#include <X11/XKBlib.h>
#include <gtk/gtk.h>
#include <time.h>

/* X key codes (evdev's plus 8) of the keys that type characters (with
   the ISO key and the Japanese keyboard's Yen and Ro), and of the letter
   keys.  */
static const guint keys[] = {
  49, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 132, 24, 25, 26, 27,
  28, 29, 30, 31, 32, 33, 34, 35, 51, 38, 39, 40, 41, 42, 43, 44, 45, 46,
  47, 48, 94, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 97,
};
static const guint letters[] = {
  24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 38, 39, 40, 41, 42, 43, 44, 45,
  46, 52, 53, 54, 55, 56, 57, 58,
};
#define LENGTH(array) (sizeof array / sizeof *array)

static enum { NONE, GTK, X11 } backend;

/* What a key types in a layout (group) at a shift level, from GTK's
   keymap or from X's.  */

static GdkKeymap *
gtk_keymap (void)
{
  GdkDisplay *display = gdk_display_get_default ();
  return display ? gdk_keymap_get_for_display (display) : NULL;
}

/* The levels are Shift and AltGr (Mod5) held or not. GTK's list of a key's
   entries has every layout but, on Wayland, each level's keysym wrong.  */
static uint32_t
gtk_key_char (guint key, int group, int level, int *groups)
{
  GdkKeymap *keymap = gtk_keymap ();
  GdkModifierType state = (level & 1 ? GDK_SHIFT_MASK : 0) | (level & 2 ? GDK_MOD5_MASK : 0);
  GdkKeymapKey *entries;
  guint keyval, *keyvals;
  gint n, effective_group, effective_level;
  if (!keymap)
    return 0;
  if (groups && gdk_keymap_get_entries_for_keycode (keymap, key, &entries, &keyvals, &n))
    {
      for (gint i = 0; i < n; i++)
        if (entries[i].group >= *groups)
          *groups = entries[i].group + 1;
      g_free (entries);
      g_free (keyvals);
    }
  if (!gdk_keymap_translate_keyboard_state (keymap, key, state, group, &keyval,
                                            &effective_group, &effective_level, NULL)
      || effective_group != group || effective_level != level)
    return 0;
  return gdk_keyval_to_unicode (keyval);
}

static Display *x_display;
static XkbDescPtr x_keymap_cache;
static time_t x_keymap_time;

static XkbDescPtr
x_keymap (void)
{
  time_t now = time (NULL);
  if (!x_keymap_cache || now != x_keymap_time)
    {
      if (x_keymap_cache)
        XkbFreeKeyboard (x_keymap_cache, 0, True);
      x_keymap_cache = XkbGetMap (x_display, XkbAllClientInfoMask, XkbUseCoreKbd);
      x_keymap_time = now;
    }
  return x_keymap_cache;
}

static uint32_t
x_key_char (guint key, int group, int level, int *groups)
{
  XkbDescPtr keymap = x_keymap ();
  if (!keymap || key < keymap->min_key_code || key > keymap->max_key_code)
    return 0;
  int n = XkbKeyNumGroups (keymap, key);
  if (groups && n > *groups)
    *groups = n;
  if (group >= n || level >= XkbKeyGroupWidth (keymap, key, group))
    return 0;
  return gdk_keyval_to_unicode (XkbKeySymEntry (keymap, key, level, group));
}

static uint32_t
key_char (guint key, int group, int level, int *groups)
{
  return backend == GTK ? gtk_key_char (key, group, level, groups)
                        : x_key_char (key, group, level, groups);
}

/* Whether a layout is Latin; how many layouts there are.  */
static int
latin_p (int group, int *groups)
{
  int count = 0;
  for (size_t i = 0; i < LENGTH (letters); i++)
    {
      uint32_t c = key_char (letters[i], group, 0, groups);
      count += c >= 'a' && c <= 'z';
    }
  return LATIN (count);
}

/* The last key pressed, as GTK gave it, and the Latin layout last typed in.  */
static struct
{
  int set, group;
  guint key;
  uint32_t c;
} last;
static int last_latin = -1;

static gboolean
on_key_press (GSignalInvocationHint *hint, guint n, const GValue *values, gpointer data)
{
  GdkEvent *event = n >= 2 ? g_value_get_boxed (&values[1]) : NULL;
  if (event && event->type == GDK_KEY_PRESS)
    {
      last.set = 1;
      last.group = event->key.group;
      last.key = event->key.hardware_keycode;
      last.c = gdk_keyval_to_unicode (event->key.keyval);
    }
  return TRUE;
}

static int
current (void)
{
  XkbStateRec state;
  if (backend == GTK)
    return last.set ? last.group : 0;
  if (backend == X11 && XkbGetState (x_display, XkbUseCoreKbd, &state) == Success)
    return state.group;
  return 0;
}

/* The Latin layout last typed in, else the first.  */
static int
latin_layout (void)
{
  int groups = 0;
  latin_p (0, &groups);
  if (last_latin >= 0 && last_latin < groups && latin_p (last_latin, NULL))
    return last_latin;
  for (int group = 0; group < groups; group++)
    if (latin_p (group, NULL))
      return group;
  return -1;
}

static int
match (guint key, int group, uint32_t c, int to)
{
  for (int level = 0; level < 4; level++)
    if (key_char (key, group, level, NULL) == c)
      {
        uint32_t latin = key_char (key, to, level, NULL);
        return latin && latin != c ? (int) latin : 0;
      }
  return -1;
}

static uint32_t
latin (uint32_t c)
{
  int group, to, result;
  if (backend == NONE)
    return 0;
  group = current ();
  if (latin_p (group, NULL))
    {
      last_latin = group;
      return 0;
    }
  if ((to = latin_layout ()) < 0)
    return 0;
  /* The key just pressed, else the first that types C.  */
  if (backend == GTK && last.set && last.c == c
      && (result = match (last.key, group, c, to)) >= 0)
    return result;
  for (size_t i = 0; i < LENGTH (keys); i++)
    if ((result = match (keys[i], group, c, to)) >= 0)
      return result;
  return 0;
}

static int
start (const char *window_system, const char *display)
{
  static gulong hook;
  if (!strcmp (window_system, "pgtk"))
    {
      if (!hook)
        {
          g_type_class_ref (GTK_TYPE_WIDGET);
          hook = g_signal_add_emission_hook (g_signal_lookup ("key-press-event", GTK_TYPE_WIDGET),
                                             0, on_key_press, NULL, NULL);
        }
      backend = GTK;
    }
  else if (!strcmp (window_system, "x"))
    {
      int opcode, event, error, major = XkbMajorVersion, minor = XkbMinorVersion;
      if (!x_display)
        x_display = XkbOpenDisplay (display[0] ? (char *) display : NULL, &event, &error,
                                    &major, &minor, &opcode);
      backend = x_display ? X11 : NONE;
    }
  return backend != NONE;
}

static void
describe (char *out, size_t size)
{
  int group = backend == NONE ? -1 : current ();
  snprintf (out, size, "(%d %d %s)", group, backend == NONE ? -1 : latin_layout (),
            group >= 0 && latin_p (group, NULL) ? "t" : "nil");
}

#endif

static emacs_value
Fstart (emacs_env *env, ptrdiff_t nargs, emacs_value *args, void *data)
{
  char window_system[32] = "", display[256] = "";
  ptrdiff_t size = sizeof window_system;
  if (!env->copy_string_contents (env, args[0], window_system, &size))
    return lisp_nil (env);
  size = sizeof display;
  if (nargs > 1 && env->is_not_nil (env, args[1])
      && !env->copy_string_contents (env, args[1], display, &size))
    return lisp_nil (env);
  return start (window_system, display) ? env->intern (env, "t") : lisp_nil (env);
}

static emacs_value
Flatin (emacs_env *env, ptrdiff_t nargs, emacs_value *args, void *data)
{
  intmax_t c = env->extract_integer (env, args[0]);
  uint32_t result;
  if (env->non_local_exit_check (env) != emacs_funcall_exit_return || c <= 0)
    return lisp_nil (env);
  result = latin ((uint32_t) c);
  return result ? env->make_integer (env, result) : lisp_nil (env);
}

static emacs_value
Flayout (emacs_env *env, ptrdiff_t nargs, emacs_value *args, void *data)
{
  char text[512];
  emacs_value string;
  describe (text, sizeof text);
  string = env->make_string (env, text, strlen (text));
  return env->funcall (env, env->intern (env, "read"), 1, &string);
}

static void
defun (emacs_env *env, const char *name, ptrdiff_t min, ptrdiff_t max,
       emacs_value (*function) (emacs_env *, ptrdiff_t, emacs_value *, void *),
       const char *doc)
{
  emacs_value args[] = { env->intern (env, name),
                         env->make_function (env, min, max, function, doc, NULL) };
  env->funcall (env, env->intern (env, "defalias"), 2, args);
}

int
emacs_module_init (struct emacs_runtime *runtime)
{
  emacs_env *env = runtime->get_environment (runtime);
  emacs_value feature;
  defun (env, "my-keyboard-start", 1, 2, Fstart,
         "Follow the keyboard of a frame in WINDOW-SYSTEM's name, on DISPLAY.\n\n"
         "(fn WINDOW-SYSTEM &optional DISPLAY)");
  defun (env, "my-keyboard-latin", 1, 1, Flatin,
         "The character CHAR's key types in the Latin layout, or nil.\n"
         "Nil too when the layout in use is Latin.\n\n(fn CHAR)");
  defun (env, "my-keyboard-layout", 0, 0, Flayout,
         "The layout in use, the Latin one, and whether the first is Latin.");
  feature = env->intern (env, "my-keyboard");
  env->funcall (env, env->intern (env, "provide"), 1, &feature);
  return 0;
}
