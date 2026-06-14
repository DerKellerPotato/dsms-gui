"""Unit tests for the GUI config parse/serialize logic (dsms-gui).

No GTK or display required — only the pure-Python parse_config(),
serialize_config(), ALL_KEYS, HIDDEN_KEYS, and SCHEMA are tested.
"""

import os
import re
import types
import unittest

# ---------------------------------------------------------------------------
# Import only the non-GTK symbols from dsms-gui.
# We stub the gi / Gtk import so tests run on a headless system.
# ---------------------------------------------------------------------------
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GUI_PATH = os.path.join(REPO, "dsms-gui")


def _load_gui_module():
    """Extract and exec only the pure-Python portion of dsms-gui.

    GTK widget classes (everything from the first 'class ' onward) require a
    display and GObject metaclasses — unusable in headless tests. We truncate
    the source just before those class definitions, strip the gi import lines,
    and exec the remainder in an isolated namespace. That gives us SCHEMA,
    parse_config, serialize_config, ALL_KEYS, and HIDDEN_KEYS without GTK.
    """
    with open(GUI_PATH) as f:
        source = f.read()

    # Drop everything from the first top-level class definition onward.
    # All pure-Python symbols (SCHEMA, parse_config, etc.) appear before them.
    # Use a simple string search — regex MULTILINE ^ issues with \r\n on Windows FS.
    idx = source.find("\nclass ")
    if idx != -1:
        source = source[:idx]

    # Strip gi / GTK import lines — not needed for the pure-Python symbols.
    source = re.sub(r'[^\n]*import gi[^\n]*', '', source)
    source = re.sub(r'[^\n]*gi\.require_version[^\n]*', '', source)
    source = re.sub(r'[^\n]*from gi\.repository[^\n]*', '', source)

    # exec() doesn't set __file__; dsms-gui uses it in module-level constants.
    ns: dict = {"__file__": GUI_PATH}
    exec(compile(source, GUI_PATH, "exec"), ns)   # noqa: S102
    return types.SimpleNamespace(**ns)


gui = _load_gui_module()
parse_config = gui.parse_config
serialize_config = gui.serialize_config
SCHEMA = gui.SCHEMA
ALL_KEYS = gui.ALL_KEYS
HIDDEN_KEYS = gui.HIDDEN_KEYS


class TestParseConfig(unittest.TestCase):

    def test_simple_key_value(self):
        text = 'DOMAIN_TYPE="ad"\nAD_DOMAIN="company.local"\n'
        v = parse_config(text)
        self.assertEqual(v["DOMAIN_TYPE"], "ad")
        self.assertEqual(v["AD_DOMAIN"], "company.local")

    def test_empty_value(self):
        v = parse_config('AD_SERVER=""\n')
        self.assertEqual(v["AD_SERVER"], "")

    def test_multiline_value(self):
        text = 'HOSTS_ENTRIES="192.168.1.1 nas\n192.168.1.2 dc"\n'
        v = parse_config(text)
        self.assertIn("\n", v["HOSTS_ENTRIES"])
        self.assertIn("nas", v["HOSTS_ENTRIES"])

    def test_unknown_keys_ignored(self):
        text = 'UNKNOWN_KEY="whatever"\nDOMAIN_TYPE="none"\n'
        v = parse_config(text)
        self.assertIn("UNKNOWN_KEY", v)   # parse doesn't filter
        self.assertEqual(v["DOMAIN_TYPE"], "none")

    def test_comment_lines_ignored(self):
        text = '# This is a comment\nDOMAIN_TYPE="ad"\n'
        v = parse_config(text)
        self.assertNotIn("# This is a comment", v)
        self.assertEqual(v["DOMAIN_TYPE"], "ad")

    def test_empty_string_produces_empty_dict(self):
        v = parse_config("")
        self.assertEqual(v, {})


class TestSerializeConfig(unittest.TestCase):

    def _all_schema_keys(self):
        return {f[0] for _, fields in SCHEMA for f in fields}

    def test_all_schema_keys_present(self):
        values = {k: "testval" for k in self._all_schema_keys()}
        out = serialize_config(values)
        for key in self._all_schema_keys():
            self.assertIn(f'{key}="testval"', out, msg=f"key {key!r} missing")

    def test_missing_key_defaults_to_empty_string(self):
        out = serialize_config({})
        self.assertIn('DOMAIN_TYPE=""', out)
        self.assertIn('AD_DOMAIN=""', out)

    def test_hidden_key_serialized_when_present(self):
        out = serialize_config({"JOIN_PASSWORD": "secret123"})
        self.assertIn('JOIN_PASSWORD="secret123"', out)

    def test_hidden_key_absent_when_not_in_values(self):
        out = serialize_config({})
        for hk in HIDDEN_KEYS:
            self.assertNotIn(f'{hk}=', out,
                             msg=f"hidden key {hk!r} must not appear when not in values")

    def test_section_headers_present(self):
        out = serialize_config({})
        for section, _ in SCHEMA:
            self.assertIn(f"# --- {section} ---", out)

    def test_roundtrip(self):
        original = {
            "DOMAIN_TYPE": "ad",
            "AD_DOMAIN": "company.local",
            "AD_REALM": "COMPANY.LOCAL",
            "HOME_MODE": "sync_ssh",
            "DSMS_SERVER": "nas.company.local",
            "HOSTS_ENTRIES": "192.168.1.1 nas\n192.168.1.2 dc",
        }
        serialized = serialize_config(original)
        reparsed = parse_config(serialized)
        for key, val in original.items():
            self.assertEqual(reparsed.get(key), val,
                             msg=f"roundtrip mismatch for {key!r}")

    def test_ends_with_newline(self):
        out = serialize_config({})
        self.assertTrue(out.endswith("\n"), "serialized output must end with newline")


class TestSchema(unittest.TestCase):

    def test_all_keys_unique(self):
        keys = [f[0] for _, fields in SCHEMA for f in fields]
        self.assertEqual(len(keys), len(set(keys)), "duplicate keys in SCHEMA")

    def test_all_keys_in_all_keys_list(self):
        schema_keys = {f[0] for _, fields in SCHEMA for f in fields}
        self.assertEqual(schema_keys, set(ALL_KEYS))

    def test_hidden_keys_not_in_schema(self):
        schema_keys = {f[0] for _, fields in SCHEMA for f in fields}
        for hk in HIDDEN_KEYS:
            self.assertNotIn(hk, schema_keys,
                             msg=f"hidden key {hk!r} should not appear in SCHEMA")

    def test_choice_fields_have_choices(self):
        for _, fields in SCHEMA:
            for f in fields:
                if len(f) >= 3 and f[2] == "choice":
                    self.assertGreaterEqual(len(f), 5,
                        msg=f"choice field {f[0]!r} missing choices list")
                    self.assertIsInstance(f[4], list)
                    self.assertGreater(len(f[4]), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
