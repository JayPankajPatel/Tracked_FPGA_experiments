"""FABulous BTS wrapper: vectors/golden come from the plain binary_stochastic_converter_sync
simulation (the wrapper only renames clk->UserCLK); hardware runs the wrapper itself."""
import importlib.util
import os

_p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "binary_stochastic_converter", "record.py")
_spec = importlib.util.spec_from_file_location("base_record_bts", _p)
_m = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_m)
record = _m.record
