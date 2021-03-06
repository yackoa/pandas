
from cpython cimport PyTypeObject

cdef extern from *:
    """
    PyObject* char_to_string(const char* data) {
    #if PY_VERSION_HEX >= 0x03000000
        return PyUnicode_FromString(data);
    #else
        return PyString_FromString(data);
    #endif
    }
    """
    object char_to_string(const char* data)


cdef extern from "Python.h":
    # Note: importing extern-style allows us to declare these as nogil
    # functions, whereas `from cpython cimport` does not.
    bint PyUnicode_Check(object obj) nogil
    bint PyString_Check(object obj) nogil
    bint PyBool_Check(object obj) nogil
    bint PyFloat_Check(object obj) nogil
    bint PyComplex_Check(object obj) nogil
    bint PyObject_TypeCheck(object obj, PyTypeObject* type) nogil

    # Note that following functions can potentially raise an exception,
    # thus they cannot be declared 'nogil'. Also PyUnicode_AsUTF8AndSize() can
    # potentially allocate memory inside in unlikely case of when underlying
    # unicode object was stored as non-utf8 and utf8 wasn't requested before.
    bint PyBytes_AsStringAndSize(object obj, char** buf,
                                 Py_ssize_t* length) except -1
    const char* PyUnicode_AsUTF8AndSize(object obj,
                                        Py_ssize_t* length) except NULL

from numpy cimport int64_t

cdef extern from "numpy/arrayobject.h":
    PyTypeObject PyFloatingArrType_Type

cdef extern from "numpy/ndarrayobject.h":
    PyTypeObject PyTimedeltaArrType_Type
    PyTypeObject PyDatetimeArrType_Type
    PyTypeObject PyComplexFloatingArrType_Type
    PyTypeObject PyBoolArrType_Type

    bint PyArray_IsIntegerScalar(obj) nogil
    bint PyArray_Check(obj) nogil

cdef extern from  "numpy/npy_common.h":
    int64_t NPY_MIN_INT64


cdef inline int64_t get_nat():
    return NPY_MIN_INT64


# --------------------------------------------------------------------
# Type Checking

cdef inline bint is_integer_object(object obj) nogil:
    """
    Cython equivalent of

    `isinstance(val, (int, long, np.integer)) and not isinstance(val, bool)`

    Parameters
    ----------
    val : object

    Returns
    -------
    is_integer : bool

    Notes
    -----
    This counts np.timedelta64 objects as integers.
    """
    return not PyBool_Check(obj) and PyArray_IsIntegerScalar(obj)


cdef inline bint is_float_object(object obj) nogil:
    """
    Cython equivalent of `isinstance(val, (float, np.complex_))`

    Parameters
    ----------
    val : object

    Returns
    -------
    is_float : bool
    """
    return (PyFloat_Check(obj) or
            (PyObject_TypeCheck(obj, &PyFloatingArrType_Type)))


cdef inline bint is_complex_object(object obj) nogil:
    """
    Cython equivalent of `isinstance(val, (complex, np.complex_))`

    Parameters
    ----------
    val : object

    Returns
    -------
    is_complex : bool
    """
    return (PyComplex_Check(obj) or
            PyObject_TypeCheck(obj, &PyComplexFloatingArrType_Type))


cdef inline bint is_bool_object(object obj) nogil:
    """
    Cython equivalent of `isinstance(val, (bool, np.bool_))`

    Parameters
    ----------
    val : object

    Returns
    -------
    is_bool : bool
    """
    return (PyBool_Check(obj) or
            PyObject_TypeCheck(obj, &PyBoolArrType_Type))


cdef inline bint is_timedelta64_object(object obj) nogil:
    """
    Cython equivalent of `isinstance(val, np.timedelta64)`

    Parameters
    ----------
    val : object

    Returns
    -------
    is_timedelta64 : bool
    """
    return PyObject_TypeCheck(obj, &PyTimedeltaArrType_Type)


cdef inline bint is_datetime64_object(object obj) nogil:
    """
    Cython equivalent of `isinstance(val, np.datetime64)`

    Parameters
    ----------
    val : object

    Returns
    -------
    is_datetime64 : bool
    """
    return PyObject_TypeCheck(obj, &PyDatetimeArrType_Type)


cdef inline bint is_array(object val):
    """
    Cython equivalent of `isinstance(val, np.ndarray)`

    Parameters
    ----------
    val : object

    Returns
    -------
    is_ndarray : bool
    """
    return PyArray_Check(val)


cdef inline bint is_period_object(object val):
    """
    Cython equivalent of `isinstance(val, pd.Period)`

    Parameters
    ----------
    val : object

    Returns
    -------
    is_period : bool
    """
    return getattr(val, '_typ', '_typ') == 'period'


cdef inline bint is_offset_object(object val):
    """
    Check if an object is a DateOffset object.

    Parameters
    ----------
    val : object

    Returns
    -------
    is_date_offset : bool
    """
    return getattr(val, '_typ', None) == "dateoffset"


cdef inline bint is_nan(object val):
    """
    Check if val is a Not-A-Number float or complex, including
    float('NaN') and np.nan.

    Parameters
    ----------
    val : object

    Returns
    -------
    is_nan : bool
    """
    return (is_float_object(val) or is_complex_object(val)) and val != val


cdef inline const char* get_c_string_buf_and_size(object py_string,
                                                  Py_ssize_t *length):
    """
    Extract internal char* buffer of unicode or bytes object `py_string` with
    getting length of this internal buffer saved in `length`.

    Notes
    -----
    Python object owns memory, thus returned char* must not be freed.
    `length` can be NULL if getting buffer length is not needed.

    Parameters
    ----------
    py_string : object
    length : Py_ssize_t*

    Returns
    -------
    buf : const char*
    """
    cdef:
        const char *buf

    if PyUnicode_Check(py_string):
        buf = PyUnicode_AsUTF8AndSize(py_string, length)
    else:
        PyBytes_AsStringAndSize(py_string, <char**>&buf, length)
    return buf


cdef inline const char* get_c_string(object py_string):
    return get_c_string_buf_and_size(py_string, NULL)
