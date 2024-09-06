# Production eHive pipeline diagrams

This directory contains a set of DOT files (extension `.gv`), representing
eHive pipelines used in Ensembl comparative genomics production processes.

If you wish, you can generate the pipeline graph for each of these
pipelines using software such as the GraphViz `dot` tool.

For example, the following command may be used to generate
a protein-trees pipeline diagram in PNG format:
```bash
dot -T png ProteinTrees.gv > ProteinTrees.png
```