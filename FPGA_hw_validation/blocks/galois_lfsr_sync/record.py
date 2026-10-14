"""Sync-reset twin: reuse galois_lfsr/record.py unchanged except for sync-reset expectations (HWB_SYNC=1)."""
import importlib.util
import os

_p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "galois_lfsr", "record.py")
_spec = importlib.util.spec_from_file_location("base_record_galois_lfsr", _p)
_m = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_m)
record = _m.record
