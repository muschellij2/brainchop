#' Get Devices Available for `tinygrad`/`brainchop`
#'
#' @returns A `data.frame` similar to `tinygrad.device`
#' @export
#'
#' @examples
#' bc_devices()
bc_devices = function() {
  tg = reticulate::import("tinygrad")
  tg_device = tg$device
  Tensor = tg$Tensor
  devices = tg_device$ALL_DEVICES
  df = data.frame(
    device = devices,
    test = NA
  )

  opts = options()
  on.exit({
    options(opts)
  })
  options(reticulate.repl.quiet = TRUE)

  for (i in seq(nrow(df))) {
    device = df$device[i]

    capture.output({
      suppressMessages({
        suppressWarnings({
          result = try({
            test = Tensor(c(1,2,3), device=device) * 2
            test = test$tolist()
            test
          }, silent = TRUE)
        })
      })
    })
    if (inherits(result, "try-error")) {
      df$test[i] = FALSE
    } else
      df$test[i] = all(result == c(2,4,6))
  }
  return(df)
}
