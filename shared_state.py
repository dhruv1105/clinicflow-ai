# shared_state.py
# In-memory role store — survives across ADK sessions within same process
_STORE: dict[str, dict] = {}

def set_user(user_id: str, data: dict):
    _STORE[user_id] = data

def get_user(user_id: str) -> dict:
    return _STORE.get(user_id, {})