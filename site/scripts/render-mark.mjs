#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { Resvg } from "@resvg/resvg-js";

const [markPath, width, foreground] = process.argv.slice(2);
const svg = readFileSync(markPath, "utf8").replace('fill="currentColor"', `fill="${foreground}"`);
const png = new Resvg(svg, {
  fitTo: { mode: "width", value: Number(width) },
}).render().asPng();

process.stdout.write(png);
