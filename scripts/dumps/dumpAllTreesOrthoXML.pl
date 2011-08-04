#! /usr/bin/perl -w

use strict;

use Getopt::Long;
use Pod::Usage;

use Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

# TODO a bit of POD documentation is probably a good idea, at least to make the help and man commands useful :)

=head2

This script dumps all the trees in the OrthoXMl format, and works for both protein trees and ncRNA trees
Works better with some database connection parameters

./dumpAllTreesOrthoXML.pl -user ensro -port 4311 -host 127.0.0.1 -database lg4_ensembl_compara_63 -adaptor NCTree

=cut

my $opts = {};
my @flags = qw(database=s user=s port=i host=s password=s help man adaptor=s output=s);
GetOptions($opts, @flags) or pod2usage(1);
pod2usage( -exitstatus => 0, -verbose => 1 ) if $opts->{help};
pod2usage( -exitstatus => 0, -verbose => 2 ) if $opts->{man};

pod2usage( -exitstatus => 0, -verbose => 2 ) if scalar(keys %$opts) == 0;

die "adaptor name (ProteinTree or NCTree) must be given\n" if not defined ${$opts}{adaptor};

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => ${$opts}{host},
                                                     -port   => ${$opts}{port},
                                                     -user   => ${$opts}{user},
                                                     -dbname => ${$opts}{database},
	                                               -pass   => ${$opts}{password});
my $file_handle = IO::File->new(${$opts}{output}, 'w');

my $s = 'get_'.${$opts}{adaptor}.'Adaptor';
my $ta = $db->$s;

my $w = Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter->new(
   -HANDLE => $file_handle
);
my $gdba = $db->get_GenomeDBAdaptor;
my $ma = $db->get_MemberAdaptor;

my $list_species = $gdba->fetch_all;
sub callback_list_members {
  my ($species) = @_;
  my $constraint = 'm.genome_db_id = '.($species->dbID);
  my $join = [[[$ta->_get_table_prefix().'_tree_member', 'tm'], 'm.member_id = tm.member_id', [qw(tm.member_id)]]];
  return $ma->_generic_fetch($constraint, $join);
}
my $list_trees = $ta->fetch_all;
$w->write_data($list_species, \&callback_list_members, $list_trees);

$w->finish();
$file_handle->close();

