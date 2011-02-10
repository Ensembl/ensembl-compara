/***
 * Created:  unknown
 * Author:   liheng
 * Last MDF: 2005-01-13
 *
 *
 * 2005-01-13 liheng:
 *
 *     * add merge component
 */
#include <string.h>
#include <stdlib.h>
#ifndef _WIN32
#include <unistd.h>
#endif
#include <time.h>
#include "tree.h"
#include "phyml.h"

int tr_sdi_task(int argc, char *argv[]);
int tr_build(int argc, char *argv[]);
int tr_root_task(int argc, char *argv[]);
int tr_reformat_task(int argc, char *argv[]);
int tr_filter_task(int argc, char *argv[]);
int tr_trans_task(int argc, char *argv[]);
int tr_treedist_task(int argc, char *argv[]);
int tr_leaf_task(int argc, char *argv[]);
int tr_mfa2aln_task(int argc, char *argv[]);
int tr_ortho_task(int argc, char *argv[]);
int tr_distmat_task(int argc, char *argv[]);
int tr_mmerge_task(int argc, char *argv[]);
int pwalign_task(int argc, char *argv[]);
int tr_subtree_task(int argc, char *argv[]);
int tr_simulate_task(int argc, char *argv[]);
int tr_sortleaf_task(int argc, char *argv[]);
int tr_estlen_task(int argc, char *argv[]);
int best_task(int argc, char *argv[]);
int plot_eps_task(int argc, char *argv[]);
int ma_backtrans_task(int argc, char *argv[]);
int tr_trimpoor_task(int argc, char *argv[]);

void usage()
{
	fprintf(stderr, "\n");
	fprintf(stderr, "Program: TreeBeST (gene Tree Building guided by Species Tree)\n");
	fprintf(stderr, "Version: %s build %s\n", TR_VERSION, TR_BUILD);
	fprintf(stderr, "Contact: Heng Li <lh3@sanger.ac.uk>\n\n");
	fprintf(stderr, "Usage:   treebest <command> [options]\n\n");
	fprintf(stderr, "Command: nj        build neighbour-joining tree, SDI, rooting\n");
	fprintf(stderr, "         best      build tree with the help of a species tree\n");
	fprintf(stderr, "         phyml     build phyml tree\n");
	fprintf(stderr, "         sdi       speciation vs. duplication inference\n");
	fprintf(stderr, "         spec      print species tree\n");
	fprintf(stderr, "         format    reformat a tree\n");
	fprintf(stderr, "         filter    filter a multi-alignment\n");
	fprintf(stderr, "         trans     translate coding nucleotide alignment\n");
	fprintf(stderr, "         backtrans translate aa alignment back to nt\n");
	fprintf(stderr, "         leaf      get external nodes\n");
	fprintf(stderr, "         mfa2aln   convert MFA to ALN format\n");
	fprintf(stderr, "         ortho     ortholog/paralog inference\n");
	fprintf(stderr, "         distmat   distance matrix\n");
	fprintf(stderr, "         treedist  topological distance between two trees\n");
	fprintf(stderr, "         pwalign   pairwise alignment\n");
	fprintf(stderr, "         mmerge    merge a forest\n");
	fprintf(stderr, "         export    export a tree to EPS format\n");
	fprintf(stderr, "         subtree   extract the subtree\n");
	fprintf(stderr, "         simulate  simulate a gene tree\n");
	fprintf(stderr, "         sortleaf  sort leaf order\n");
	fprintf(stderr, "         estlen    estimate branch length\n");
	fprintf(stderr, "         trimpoor  trim out leaves that affect the quality of a tree\n");
	fprintf(stderr, "         root      root a tree by minimizing height\n\n");
}
int main(int argc, char *argv[])
{
#ifdef _WIN32
	srand(time(0));
#else
	srand48(time(0)^((int)getpid()));
#endif
	if (argc == 1) {
		usage();
		return 1;
	}
	if (strcmp(argv[1], "nj") == 0)
		return tr_build(argc-1, argv+1);
	else if (strcmp(argv[1], "best") == 0)
		return best_task(argc-1, argv+1);
	else if (strcmp(argv[1], "phyml") == 0)
		return phyml_task(argc-1, argv+1);
	else if (strcmp(argv[1], "sdi") == 0)
		return tr_sdi_task(argc-1, argv+1);
	else if (strcmp(argv[1], "root") == 0)
		return tr_root_task(argc-1, argv+1);
	else if (strcmp(argv[1], "format") == 0)
		return tr_reformat_task(argc-1, argv+1);
	else if (strcmp(argv[1], "filter") == 0)
		return tr_filter_task(argc-1, argv+1);
	else if (strcmp(argv[1], "trans") == 0)
		return tr_trans_task(argc-1, argv+1);
	else if (strcmp(argv[1], "backtrans") == 0)
		return ma_backtrans_task(argc-1, argv+1);
	else if (strcmp(argv[1], "leaf") == 0)
		return tr_leaf_task(argc-1, argv+1);
	else if (strcmp(argv[1], "treedist") == 0)
		return tr_treedist_task(argc-1, argv+1);
	else if (strcmp(argv[1], "mfa2aln") == 0)
		return tr_mfa2aln_task(argc-1, argv+1);
	else if (strcmp(argv[1], "ortho") == 0)
		return tr_ortho_task(argc-1, argv+1);
	else if (strcmp(argv[1], "distmat") == 0)
		return tr_distmat_task(argc-1, argv+1);
	else if (strcmp(argv[1], "pwalign") == 0)
		return pwalign_task(argc-1, argv+1);
	else if (strcmp(argv[1], "mmerge") == 0)
		return tr_mmerge_task(argc-1, argv+1);
	else if (strcmp(argv[1], "export") == 0)
		return plot_eps_task(argc-1, argv+1);
	else if (strcmp(argv[1], "subtree") == 0)
		return tr_subtree_task(argc-1, argv+1);
	else if (strcmp(argv[1], "simulate") == 0)
		return tr_simulate_task(argc-1, argv+1);
	else if (strcmp(argv[1], "sortleaf") == 0)
		return tr_sortleaf_task(argc-1, argv+1);
	else if (strcmp(argv[1], "estlen") == 0)
		return tr_estlen_task(argc-1, argv+1);
	else if (strcmp(argv[1], "trimpoor") == 0)
		return tr_trimpoor_task(argc-1, argv+1);
	else if (strcmp(argv[1], "spec") == 0) {
		extern char *tr_species_tree_string;
		printf("%s\n", tr_species_tree_string);
		return 0;
	} else {
		fprintf(stderr, "[main] unrecognized command %s\n", argv[1]);
		return 1;
	}
	return 0;
}
