.onLoad <- function(libname, pkgname) {
  reticulate::py_require("brainchop", python_version = "3.10")
}
