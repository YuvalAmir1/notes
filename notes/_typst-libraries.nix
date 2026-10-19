# Typst Universe's packages that notes in mathematics, physics and computer
# science need most, installed (as @preview/…, offline), with the lines that
# set each up in a note (SPC i l, my-notes.el).
{ pkgs, lib }:
let
  libraries =
    let
      use = package: ''#import "@preview/${package.pname}:${package.version}"'';
    in
    with pkgs.typstPackages;
    [
      {
        packages = [ physica ];
        about = "Physics notation: derivatives, vectors, bra-kets, tensors";
        setup = "${use physica}: *";
      }
      {
        packages = [ unify ];
        about = "Numbers and SI units, with uncertainties";
        setup = "${use unify}: num, qty, unit, numrange, qtyrange";
      }
      {
        packages = [ quill ];
        about = "Quantum circuits";
        setup = "${use quill}: *";
      }
      {
        packages = [ zap ];
        about = "Electric circuits";
        setup = use zap;
      }
      {
        packages = [ cetz ];
        about = "Drawings, as TikZ makes them";
        setup = use cetz;
      }
      {
        packages = [ cetz-plot ];
        about = "Plots and charts in CeTZ drawings";
        setup = ''
          ${use cetz}
          ${use cetz-plot}: plot, chart'';
      }
      {
        # And what its contours, box plots, violins and jitter import as
        # they're drawn.
        packages = [
          lilaq
          komet_0_1_0
          komet_0_2_0
          suiji_0_5_1
        ];
        about = "Plots of data and functions, with error bars";
        setup = "${use lilaq} as lq";
      }
      {
        packages = [ fletcher ];
        about = "Diagrams of nodes and arrows: commutative diagrams, flowcharts";
        setup = "${use fletcher} as fletcher: diagram, node, edge";
      }
      {
        packages = [ finite ];
        about = "Finite automata";
        setup = "${use finite} as finite: automaton";
      }
      {
        packages = [ theorion ];
        about = "Theorems, definitions and proofs";
        setup = ''
          ${use theorion}: *
          #show: show-theorion'';
      }
      {
        packages = [ equate ];
        about = "Equations numbered line by line";
        setup = ''
          ${use equate}: equate
          #show: equate.with(breakable: true, sub-numbering: true)
          #set math.equation(numbering: "(1.1)")'';
      }
      {
        packages = [ mitex ];
        about = "LaTeX's math, written as in LaTeX";
        setup = "${use mitex}: mi, mitex, mitex-convert";
      }
      {
        packages = [ lovelace ];
        about = "Pseudocode";
        setup = "${use lovelace}: pseudocode-list, line-label";
      }
      {
        packages = [
          codly
          codly-languages
        ];
        about = "Code blocks with line numbers and their languages' icons";
        setup = ''
          ${use codly}: *
          ${use codly-languages}: *
          #show: codly-init.with()
          #codly(languages: codly-languages)'';
      }
      {
        packages = [ curryst ];
        about = "Proof trees, for logic and type systems";
        setup = "${use curryst}: rule, prooftree, rule-set";
      }
      {
        packages = [ diagraph ];
        about = "Graphs in Graphviz's DOT language";
        setup = "${use diagraph}: render, raw-render, adjacency";
      }
      {
        packages = [ gentle-clues ];
        about = "Boxes for tips, notes and warnings";
        setup = "${use gentle-clues}: *";
      }
      {
        # Its empty tables and Karnaugh maps tell a cell's value by comparing
        # its type with a string, which Typst no longer does.
        packages = [
          (truthfy.overrideAttrs {
            postPatch = ''
              substituteInPlace main.typ --replace-fail 'type(a) != "content"' 'type(a) != content'
            '';
          })
        ];
        about = "Truth tables and Karnaugh maps";
        setup = "${use truthfy}: truth-table, truth-table-empty, karnaugh-empty, NAND, NOR";
      }
    ];
in
{
  # They and the packages they import, as Typst lays packages out by name
  # and version: the `preview` folder of a package path.
  typstLibraries = "${
    pkgs.symlinkJoin {
      name = "typst-libraries";
      paths = lib.closePropagation (lib.concatMap (library: library.packages) libraries);
    }
  }/lib/typst-packages";

  librariesValues = pkgs.writeText "my-typst-libraries.el" ''
    ;;; my-typst-libraries.el --- Typst's libraries installed  -*- lexical-binding: t -*-
    (defconst my-typst-libraries
      '(${
        lib.concatMapStringsSep "\n    " (
          library:
          "(${builtins.toJSON (lib.head library.packages).pname} ${builtins.toJSON library.about}\n     ${builtins.toJSON library.setup})"
        ) libraries
      })
      "Typst's libraries installed, as (NAME ABOUT SETUP): SETUP sets one up.")
    (provide 'my-typst-libraries)
  '';
}
