from pathlib import Path
import numpy
from Cython.Build import cythonize
from setuptools import Extension, setup

ROOT = Path(__file__).resolve().parent
setup(name="rcs-cython-benchmark-v2", ext_modules=cythonize([
    Extension("cython_kernel", [str(ROOT / "cython_kernel.pyx")],
              include_dirs=[numpy.get_include()],
              extra_compile_args=["-O3", "-DNDEBUG", "-march=native", "-fopenmp"],
              extra_link_args=["-fopenmp"])
], compiler_directives={"language_level": "3"}))
