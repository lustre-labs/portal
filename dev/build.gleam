import esgleam
import esgleam/mod/install
import gleam/regexp
import gleam/result
import gleam/string
import simplifile

pub fn main() {
  case simplifile.is_file("build/dev/bin/package/bin/esbuild") {
    Ok(True) -> Nil
    _ -> install.fetch()
  }

  let assert Ok(_) = bundle(minify: False)
  let assert Ok(_) = bundle(minify: True)
  let assert Ok(_) = inject_script()

  Nil
}

fn bundle(minify minify) {
  let filename = case minify {
    True -> "lustre-portal.min.mjs"
    False -> "lustre-portal.mjs"
  }

  let path = "./priv/static/" <> filename

  // For whatever reason, esgleam needs the input path to be relative to the location
  // of the esbuild binary
  let entry = "../../../../dev/entry.mjs"

  esgleam.new("")
  |> esgleam.entry(entry)
  |> esgleam.raw("--outfile=" <> path)
  |> esgleam.minify(minify)
  |> esgleam.bundle()
}

fn inject_script() {
  let script_path = "./priv/static/lustre-portal.min.mjs"
  use script <- result.try(simplifile.read(script_path))

  let module_path = "./src/lustre/portal.gleam"
  use module <- result.try(simplifile.read(module_path))

  let script =
    script
    |> string.trim
    |> string.replace("\n", "\\n")
    |> string.replace("\\", "\\\\")
    |> string.replace("\"", "\\\"")
    |> string.trim

  let inject_regexp = "// <<INJECT SCRIPT>>\\n    .+,"
  let options = regexp.Options(case_insensitive: False, multi_line: True)
  let assert Ok(re) = regexp.compile(inject_regexp, options)

  let assert [before, after] = regexp.split(re, module)

  simplifile.write(
    to: module_path,
    contents: before
      <> "// <<INJECT SCRIPT>>\n    \""
      <> script
      <> "\","
      <> after,
  )
}
