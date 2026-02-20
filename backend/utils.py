from config import DEBUG_MODE


def debug_print(msg: str, level: str = "INFO"):
    """Print colored debug output to console."""
    if not DEBUG_MODE:
        return
    colors = {
        "INFO": "\033[94m",
        "SUCCESS": "\033[92m",
        "WARNING": "\033[93m",
        "ERROR": "\033[91m",
        "HEADER": "\033[95m",
        "DATA": "\033[96m",
    }
    reset = "\033[0m"
    color = colors.get(level, "")
    print(f"{color}[{level}] {msg}{reset}")