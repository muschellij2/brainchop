#' List Brainchop Models
#'
#' @returns A list of models and a printout
#' @export
#'
#' @examples
#' bc_list_models()
bc_list_models = function() {
  bc = reticulate::import("brainchop")
  utils = bc$utils
  utils$list_models()
  AVAILABLE_MODELS = utils$AVAILABLE_MODELS
  AVAILABLE_MODELS
}
