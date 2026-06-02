///|
priv struct LoadedFile {
  file_name : String
  source : String
}

///|
extern "js" fn js_read_selected_file(input_id : String) -> @js.Promise =
  #| async (inputId) => {
  #|   const input = document.getElementById(inputId)
  #|   if (!input) {
  #|     throw new Error(`file input not found: ${inputId}`)
  #|   }
  #|   const file = input.files && input.files[0]
  #|   if (!file) {
  #|     return { fileName: "", source: "" }
  #|   }
  #|   const source = await file.text()
  #|   input.value = ""
  #|   return { fileName: file.name || "asciicast", source }
  #| }

///|
fn loaded_file_from_js(value : @js.Value) -> LoadedFile {
  {
    file_name: value.get_with_string("fileName"),
    source: value.get_with_string("source"),
  }
}
