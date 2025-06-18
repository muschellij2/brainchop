brainchop_base = function() {
  bc = reticulate::import("brainchop")
  brainchop = bc$brainchop
  brainchop
}

brainchop_base_noconvert = function() {
  bc = reticulate::import("brainchop", convert = FALSE)
  brainchop = bc$brainchop
  brainchop
}
