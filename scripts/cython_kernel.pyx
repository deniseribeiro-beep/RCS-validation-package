# cython: language_level=3, boundscheck=False, wraparound=False, cdivision=True

import numpy as np
cimport numpy as cnp
from cython.parallel cimport prange

ctypedef cnp.uint8_t u8
ctypedef cnp.float64_t f64

cdef inline void score_one(u8 matrix_code, u8 governance, f64[:, ::1] severity,
                           Py_ssize_t i, f64[::1] p_bio, f64[::1] score,
                           u8[::1] grade, u8[::1] route) noexcept nogil:
    cdef double penalty
    if matrix_code == 0:
        penalty = (severity[i, 0] * 30.0 + severity[i, 1] * 15.0 + severity[i, 2] * 10.0 +
                   severity[i, 3] * 20.0 + severity[i, 4] * 25.0)
    else:
        penalty = (severity[i, 5] * 25.0 + severity[i, 6] * 25.0 + severity[i, 7] * 15.0 +
                   severity[i, 8] * 20.0 + severity[i, 9] * 15.0)
    p_bio[i] = penalty
    score[i] = 100.0 - penalty
    if governance == 0:
        grade[i] = 4
        route[i] = 2
    else:
        if score[i] >= 90.0: grade[i] = 0
        elif score[i] >= 80.0: grade[i] = 1
        elif score[i] >= 65.0: grade[i] = 2
        elif score[i] >= 50.0: grade[i] = 3
        else: grade[i] = 4
        route[i] = 1 if score[i] < 50.0 else 0

def score(cnp.ndarray[u8, ndim=1] matrix_code,
          cnp.ndarray[u8, ndim=1] governance,
          cnp.ndarray[f64, ndim=2, mode="c"] severity, int threads=1):
    cdef Py_ssize_t n = matrix_code.shape[0]
    cdef cnp.ndarray[f64, ndim=1] p_bio = np.empty(n, dtype=np.float64)
    cdef cnp.ndarray[f64, ndim=1] rcs = np.empty(n, dtype=np.float64)
    cdef cnp.ndarray[u8, ndim=1] grade = np.empty(n, dtype=np.uint8)
    cdef cnp.ndarray[u8, ndim=1] route = np.empty(n, dtype=np.uint8)
    cdef Py_ssize_t i
    cdef u8[::1] matrix_view = matrix_code
    cdef u8[::1] governance_view = governance
    cdef f64[:, ::1] severity_view = severity
    cdef f64[::1] p_view = p_bio
    cdef f64[::1] rcs_view = rcs
    cdef u8[::1] grade_view = grade
    cdef u8[::1] route_view = route
    if threads <= 1:
        with nogil:
            for i in range(n):
                score_one(matrix_view[i], governance_view[i], severity_view, i, p_view, rcs_view, grade_view, route_view)
    else:
        with nogil:
            for i in prange(n, schedule="static", num_threads=threads):
                score_one(matrix_view[i], governance_view[i], severity_view, i, p_view, rcs_view, grade_view, route_view)
    return p_bio, rcs, grade, route
