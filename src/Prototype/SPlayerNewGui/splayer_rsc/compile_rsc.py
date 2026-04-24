#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import optparse
import re
import os.path
import zlib
import base64

BASE64_LINE_WIDTH = 76

PLACEHOLDER_RE = re.compile(r"^(?P<indent>\s*)(?P<key>[^:\n]+:\s*)<<<(?P<filename>[^<>]+)>>>\s*$")

USAGE_TEXT = """
  Usage: compile_rsc.py [OPTIONS]
         --input="/path/input.yaml"     Compile input.yaml into input.yaml_bz
"""

def encode_binary_resource(input_path, filename, indent):
  resource_path = os.path.join(input_path, filename)
  print("Binary streaming " + filename + " ...")
  sys.stdout.flush()
  with open(resource_path, "rb") as input_stream:
    encoded = base64.b64encode(input_stream.read()).decode("ascii")
  block_indent = indent + "  "
  lines = [encoded[i:i + BASE64_LINE_WIDTH] for i in range(0, len(encoded), BASE64_LINE_WIDTH)]
  return "!!binary |\n" + "\n".join(block_indent + line for line in lines)

def expand_binary_placeholders(input_text, input_path):
  output_lines = []
  for line in input_text.splitlines():
    match = PLACEHOLDER_RE.match(line)
    if match is None:
      output_lines.append(line)
      continue

    output_lines.append(
      match.group("indent") +
      match.group("key") +
      encode_binary_resource(input_path, match.group("filename"), match.group("indent")))
  return "\n".join(output_lines) + "\n"

def main():
  p = optparse.OptionParser()
  p.add_option('--input', '-i', default="")
  options, arguments = p.parse_args()

  if len(options.input) == 0:
    print(USAGE_TEXT)
    return 1

  print("Processing " + options.input + " ...")
  sys.stdout.flush()
  if os.path.isfile(options.input) == False:
    print('Error: Input file "' + options.input + '" does not exist')
    return 1

  real_input = os.path.realpath(options.input)

  m = re.search(r"^(.+[\\/])+", real_input)
  if m == None:
    print("Error: cannot retrieve path from input file: " + real_input)
    return 1
  
  input_path = m.group(1)
  print("Input path is: " + input_path)
  sys.stdout.flush()

  with open(real_input, "r", encoding="utf-8-sig") as input_stream:
    input_text = input_stream.read()

  print("Encoding resource yaml ...")
  sys.stdout.flush()
  output_yaml = options.input+"_b"
  output_stream_content = expand_binary_placeholders(input_text, input_path).encode("utf-8")
  with open(output_yaml, "wb") as output_stream:
    output_stream.write(output_stream_content)
  print("Generated " + output_yaml)
  sys.stdout.flush()

  output_yamlz = output_yaml+"z"
  with open(output_yamlz, "wb") as output_streamz:
    output_streamz.write(zlib.compress(output_stream_content, 9))
  print("Generated " + output_yamlz)
  sys.stdout.flush()
  return 0

sys.exit(main())