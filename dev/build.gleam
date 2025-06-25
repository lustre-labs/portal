import esgleam
import esgleam/mod/install
import simplifile

pub fn main() {
  case simplifile.is_file("build/dev/bin/package/bin/esbuild") {
    Ok(True) -> Nil
    _ -> install.fetch()
  }

  let _ = echo bundle(False)
  let _ = echo bundle(True)
}

fn bundle(minify) {
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
