"""Sync-reset twin: reuse stochastic_to_binary/record.py unchanged except for sync-reset expectations (HWB_SYNC=1)."""
import importlib.util
import os

_p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "stochastic_to_binary", "record.py")
_spec = importlib.util.spec_from_file_location("base_record_stochastic_to_binary", _p)
_m = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_m)
record = _m.record
