"""
Performance monitoring utilities for IPDS AI system.
"""
import time
import functools
from typing import Callable

def timing_decorator(operation_name: str):
    """Decorator to measure and log operation timing."""
    def decorator(func: Callable):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            start = time.time()
            try:
                result = func(*args, **kwargs)
                elapsed = time.time() - start
                print(f"[PERF] {operation_name}: {elapsed:.2f}s")
                
                # Log slow operations (>5s)
                if elapsed > 5.0:
                    print(f"[PERF] WARNING: Slow operation detected: {operation_name} took {elapsed:.2f}s")
                
                return result
            except Exception as e:
                elapsed = time.time() - start
                print(f"[PERF] {operation_name} FAILED after {elapsed:.2f}s: {e}")
                raise
        return wrapper
    return decorator
