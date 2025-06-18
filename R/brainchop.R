

#' Run Brain Chop/Mind Grab
#'
#' @param input input image or filename
#' @param model Model name to use, see [bc_list_models()], current options are
#' "mindgrab", "tissue_fast", "subcortical", "DKatlas", "multiaxial".
#' @param comply Insert compliance arguments to `niimath` before '-conform'
#' @param ct Is the image a CT scan? (defaults to FALSE)
#' @param crop Crop the input for faster execution. May reduce accuracy.(defaults to percentile 2 cutoff)
#' @param border Mask border threshold in mm. Default is 0. Makes a difference
#' only if the model is `mindgrab`
#' @param inverse_conform Perform inverse conformation into original image space
#' @param export_classes Export class probability maps
#' @param crop_percent Crop percent cutoff for the input image, defaults to 2L.
#' @param device device for running the model, defaults to "CPU". If
#' `NULL`, it will use the default device set in the environment.
#'
#' @returns A list of the input and output images and files created,
#' including the mask.
#' @export
#'
#' @examples
mindgrab = function(
    input,
    model = "mindgrab",
    ct = FALSE,
    comply = FALSE,
    crop = FALSE,
    crop_percent = 2L,
    border = 0L,
    inverse_conform = FALSE,
    export_classes = FALSE,
    device = c(
      "CPU",
      "NV",
      "AMD",
      "QCOM",
      "METAL",
      "CUDA",
      "GPU",
      "LLVM",
      "WEBGPU")
) {
  if (!is.null(device)) {
    device = match.arg(device)
    env_args = list(1)
    names(env_args) = device
    do.call(Sys.setenv, args = env_args)
  }

  input = neurobase::checkimg(input)
  input = path.expand(input)
  input = normalizePath(input, mustWork = TRUE)

  output = tempfile(fileext = ".nii.gz")
  mask = tempfile(fileext = ".nii.gz")

  assertthat::assert_that(
    assertthat::is.count(border) || border == 0,
    assertthat::is.flag(inverse_conform),
    assertthat::is.flag(export_classes),
    assertthat::is.flag(ct),
    assertthat::is.flag(crop)
  )
  if (crop) {
    assertthat::assert_that(
      assertthat::is.count(crop_percent)
    )
  }

  models = c("tissue_fast", "subcortical", "DKatlas", "multiaxial", "mindgrab")
  model = match.arg(model, choices = models)


  bc = reticulate::import("brainchop", convert = FALSE)

  niimath = bc$niimath
  conform = niimath$conform
  bwlabel = niimath$bwlabel
  grow_border  = niimath$grow_border
  niimath_dtype = niimath$niimath_dtype
  utils = bc$utils
  # update_models = utils$update_models
  # list_models = utils$list_models
  get_model = utils$get_model
  export_classes_fn = utils$export_classes
  AVAILABLE_MODELS = utils$AVAILABLE_MODELS
  cleanup = utils$cleanup
  crop_to_cutoff = utils$crop_to_cutoff
  pad_to_original_size = utils$pad_to_original_size


  model_obj = get_model(model)

  output_dtype = "char"
  # load input
  out = conform(input, comply = comply, ct = ct)
  volume = out[[0]]
  header = out[[1]]
  if (crop) {
    crop_percent = as.integer(crop_percent)
    crop_out = crop_to_cutoff(volume, crop_percent)
    volume = crop_out[[0]]
    coords = crop_out[[1]]
  }

  np = reticulate::import("numpy", convert = FALSE)
  # from tinygrad import Tensor, dtypes
  tg = reticulate::import("tinygrad", convert = FALSE)
  image = volume$transpose(c(2L, 1L, 0L))
  image = image$astype(np$float32)
  image = tg$Tensor(image, device = "CPU")
  image = image$rearrange(
    "... -> 1 1 ..."
  )

  output_channels = model_obj(image)

  output = output_channels$argmax(axis=1L)
  output = output$rearrange("1 x y z -> z y x")
  output = output$numpy()
  output = output$astype(np$uint8)


  if (crop) {
    output = pad_to_original_size(output, coords)
  }

  bw_out = bwlabel(header, output)
  labels = bw_out[[0]]
  new_header = bw_out[[1]]
  full_input = new_header + labels$tobytes()

  if (export_classes) {
    export_classes_fn(output_channels, header, output)
  }
  # print(f"    brainchop :: Exported classes to c[channel_number]_{args.output}")

  cmd = c("niimath", "-")
  if (inverse_conform && model != "mindgrab") {
    cmd = c(cmd, "-reslice_nn", input)
  }

  if (model == "mindgrab") {
    cmd = c("niimath", input)
  }
  if (border > 0) {
    full_input = grow_border(full_input, border)
  }
  cmdm = c("niimath", "-", "-reslice_nn", input)

  subprocess = reticulate::import("subprocess", convert = FALSE)
  subprocess$run(
    cmdm + c("-gz", "1", mask, "-odt", "char"),
    input = full_input,
    check = TRUE
  )
  cmd = c(cmd, "-reslice_mask", "-")
  output_dtype = "input_force"
  cmd = c(cmd,  "-gz", "1", output, "-odt", output_dtype)

  subprocess$run(cmd, input = full_input, check = TRUE)

  # override cleanup()
  suppressWarnings({
    file.remove("conformed.nii")
  })
  result = list(
    input = input,
    output_file = output,
    output = neurobase::readnii(output),
    mask_file = mask,
    mask = neurobase::readnii(mask)
  )
  result
}

#' @export
#' @rdname mindgrab
brainchop = mindgrab


#' @export
#' @rdname mindgrab
#' @param ... additional arguments (not used)
ct_mindgrab = function(...) {
  mindgrab(..., ct = TRUE)
}

#' @export
#' @rdname mindgrab
ct_brainchop = ct_mindgrab
