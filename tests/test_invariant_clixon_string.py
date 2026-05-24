import pytest
import ctypes
import sys


# Simulate the vulnerable pattern: allocation size vs copy size divergence
# We model the security invariant: the allocated buffer must always be >= strlen(str)+1

def safe_string_dup(s: str, len_param: int) -> bytes:
    """
    Simulates the clixon_string_dup behavior:
    - Allocates 'len_param' bytes
    - Copies strlen(str)+1 bytes
    
    Returns the duplicated string if safe, raises ValueError if unsafe.
    This is the SAFE reference implementation that enforces the invariant.
    """
    if s is None:
        raise ValueError("Input string cannot be None")
    
    # The actual bytes needed (strlen(str) + 1 for null terminator)
    actual_bytes_needed = len(s.encode('utf-8')) + 1
    
    # Security invariant: allocated size must be >= actual bytes needed
    if len_param < actual_bytes_needed:
        raise ValueError(
            f"Buffer overflow: allocated {len_param} bytes but need "
            f"{actual_bytes_needed} bytes (strlen={actual_bytes_needed - 1})"
        )
    
    # Safe to copy
    return s.encode('utf-8')


def check_allocation_safety(string_input: str, len_param: int) -> dict:
    """
    Checks whether the allocation is safe.
    Returns a dict with safety analysis.
    """
    if string_input is None:
        return {"safe": False, "reason": "null input"}
    
    encoded = string_input.encode('utf-8') if isinstance(string_input, str) else string_input
    actual_needed = len(encoded) + 1  # strlen + null terminator
    
    is_safe = len_param >= actual_needed
    
    return {
        "safe": is_safe,
        "allocated": len_param,
        "needed": actual_needed,
        "overflow_bytes": max(0, actual_needed - len_param),
        "string_len": len(encoded),
    }


# Adversarial payloads: (string_input, len_param)
# Format: (string, allocated_len)
# The invariant: allocated_len must ALWAYS be >= len(string.encode()) + 1
ADVERSARIAL_PAYLOADS = [
    # (string, len_param) - various attack scenarios
    
    # Off-by-one: len is exactly one byte short
    ("hello", 5),           # needs 6 (5 chars + null), allocated 5
    ("A", 1),               # needs 2 (1 char + null), allocated 1
    ("AB", 2),              # needs 3, allocated 2
    
    # Zero allocation
    ("hello", 0),           # needs 6, allocated 0
    ("", 0),                # needs 1 (just null), allocated 0
    
    # Negative-like (very small) allocation
    ("hello world", 1),     # needs 12, allocated 1
    
    # Long string with tiny allocation
    ("A" * 100, 10),        # needs 101, allocated 10
    ("A" * 1000, 1),        # needs 1001, allocated 1
    
    # SQL injection payload with small allocation
    ("' OR '1'='1", 5),     # needs 13, allocated 5
    
    # Path traversal payload
    ("../../../etc/passwd", 10),  # needs 20, allocated 10
    
    # Format string attack payload
    ("%s%s%s%s%s%s%s%s", 8),     # needs 17, allocated 8
    
    # Null byte injection attempt (Python string, encoded)
    ("hello\x00world", 6),       # needs 12 (encoded), allocated 6
    
    # Unicode multi-byte characters with small allocation
    ("héllo", 4),           # UTF-8 encoded is 6 bytes + null = 7, allocated 4
    ("日本語", 5),           # UTF-8 is 9 bytes + null = 10, allocated 5
    
    # Buffer boundary: exactly one less than needed
    ("AAAAAAAAAA", 10),     # needs 11, allocated 10
    
    # Integer overflow simulation: very large string, small len
    ("X" * 255, 100),       # needs 256, allocated 100
    ("X" * 256, 255),       # needs 257, allocated 255
    
    # Shell injection payload
    ("; rm -rf /", 5),      # needs 11, allocated 5
    
    # XSS payload
    ("<script>alert(1)</script>", 10),  # needs 26, allocated 10
    
    # Whitespace/control characters
    ("\t\n\r\x01\x02\x03", 3),  # needs 7, allocated 3
]

# Safe payloads that should NOT trigger the invariant violation
SAFE_PAYLOADS = [
    ("hello", 6),           # exactly right
    ("hello", 7),           # one extra byte
    ("hello", 100),         # plenty of space
    ("", 1),                # empty string needs just null terminator
    ("A", 2),               # single char + null
    ("test string", 12),    # exact fit
]


@pytest.mark.parametrize("string_input,len_param", ADVERSARIAL_PAYLOADS)
def test_buffer_allocation_invariant_adversarial(string_input, len_param):
    """
    Invariant: The allocated buffer size (len_param) must always be >= strlen(str)+1.
    When this invariant is violated, the operation must be rejected/flagged as unsafe.
    A safe implementation must NEVER allow memcpy to write beyond allocated bounds.
    """
    result = check_allocation_safety(string_input, len_param)
    
    # The invariant: if not safe, the system must detect and reject it
    # We assert that our safety checker correctly identifies the overflow
    assert result["safe"] is False, (
        f"Expected unsafe allocation to be detected: "
        f"string='{string_input[:20]}...', allocated={len_param}, "
        f"needed={result['needed']}"
    )
    
    # Verify the overflow magnitude is positive
    assert result["overflow_bytes"] > 0, (
        f"Expected positive overflow bytes but got {result['overflow_bytes']}"
    )
    
    # Verify that calling safe_string_dup raises an error (safe impl rejects it)
    with pytest.raises(ValueError, match="Buffer overflow"):
        safe_string_dup(string_input, len_param)


@pytest.mark.parametrize("string_input,len_param", SAFE_PAYLOADS)
def test_buffer_allocation_invariant_safe(string_input, len_param):
    """
    Invariant: When allocated size >= strlen(str)+1, the operation must succeed safely.
    Safe allocations must not be incorrectly rejected.
    """
    result = check_allocation_safety(string_input, len_param)
    
    assert result["safe"] is True, (
        f"Expected safe allocation: string='{string_input}', "
        f"allocated={len_param}, needed={result['needed']}"
    )
    
    assert result["overflow_bytes"] == 0, (
        f"No overflow expected but got {result['overflow_bytes']} overflow bytes"
    )
    
    # Should not raise
    dup = safe_string_dup(string_input, len_param)
    assert dup is not None
    assert len(dup) == len(string_input.encode('utf-8'))


@pytest.mark.parametrize("string_input,len_param", ADVERSARIAL_PAYLOADS)
def test_allocation_size_never_less_than_string_plus_null(string_input, len_param):
    """
    Invariant: For any string duplication operation, the fundamental security property
    is that allocated_size >= strlen(string) + 1 (null terminator).
    This must hold for ALL inputs including adversarial ones.
    """
    encoded = string_input.encode('utf-8')
    required_size = len(encoded) + 1  # strlen + null terminator
    
    # The security property: if len_param < required_size, this is a vulnerability
    # A secure implementation must enforce: len_param >= required_size
    is_vulnerable = len_param < required_size
    
    # For all adversarial payloads, we expect the vulnerability condition to be true
    # (i.e., the caller passed an insufficient len_param)
    assert is_vulnerable, (
        f"Adversarial payload should demonstrate the vulnerability condition: "
        f"len_param={len_param} should be < required_size={required_size}"
    )
    
    # The security invariant that MUST hold in a secure implementation:
    # Any secure string dup function must validate len >= strlen(str)+1
    # We verify our safe implementation enforces this
    with pytest.raises(ValueError):
        safe_string_dup(string_input, len_param)


def test_null_input_handling():
    """
    Invariant: Null/None inputs must be handled safely without crashes.
    """
    with pytest.raises((ValueError, AttributeError, TypeError)):
        safe_string_dup(None, 10)


def test_empty_string_requires_one_byte():
    """
    Invariant: Even an empty string requires at least 1 byte for the null terminator.
    Allocating 0 bytes for any string (including empty) is always unsafe.
    """
    result = check_allocation_safety("", 0)
    assert result["safe"] is False
    assert result["needed"] == 1  # just the null terminator
    assert result["overflow_bytes"] == 1


@pytest.mark.parametrize("size", [0, 1, 2, 3, 4, 5, 10, 50, 99])
def test_allocation_boundary_for_100_char_string(size):
    """
    Invariant: For a 100-character string, any allocation < 101 bytes is unsafe.
    This tests the boundary condition systematically.
    """
    test_string = "A" * 100
    result = check_allocation_safety(test_string, size)
    
    # All sizes < 101 must be detected as unsafe
    assert result["safe"] is False, (
        f"Allocation of {size} bytes for 100-char string must be detected as unsafe"
    )
    assert result["needed"] == 101


def test_allocation_exact_boundary_is_safe():
    """
    Invariant: Allocating exactly strlen(str)+1 bytes is the minimum safe allocation.
    """
    test_string = "A" * 100
    exact_size = len(test_string.encode('utf-8')) + 1  # 101
    
    result = check_allocation_safety(test_string, exact_size)
    assert result["safe"] is True
    assert result["overflow_bytes"] == 0