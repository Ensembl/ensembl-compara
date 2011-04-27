
=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::CheckReuseDB

=head1 DESCRIPTION

This Runnable checks whether the previous production is still consistent especially in regards dnafrag names

The format of the input_id follows the format of a Perl hash reference.
Example:
    { 'genome_db_id' => 90 }

supported keys:
    'genome_db_id'  => <number>
        the id of the genome to be checked (main input_id parameter)

    'reuse_db'  => <dbconn_hash>
        previous production database


=cut

package Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::CheckReuseDB;

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub run {
     my $self = shift @_;

     my $reuse_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$self->param('reuse_url'));
     my $gdb = $reuse_dba->get_GenomeDBAdaptor->fetch_by_dbID($self->param('genome_db_id'));
     my $reuse_dnafrags = $reuse_dba->get_DnafragAdaptor->fetch_all_by_GenomeDB_region($gdb);
     
     my $reuse_list;
     foreach my $dnafrag (@$reuse_dnafrags) {
	 $reuse_list->{$dnafrag->dbID}{$dnafrag->name}{$dnafrag->length}{$dnafrag->coord_system_name} = 1;
     }

     my $curr_dnafrags = $self->compara_dba->get_DnafragAdaptor->fetch_all_by_GenomeDB_region($gdb);

     my $curr_list;
     foreach my $dnafrag (@$curr_dnafrags) {
	 $curr_list->{$dnafrag->dbID}{$dnafrag->name}{$dnafrag->length}{$dnafrag->coord_system_name} = 1;
     }

     my ($old_names, $new_names);

     my ($removed, $remained1, $old_names) = $self->check_presence($reuse_list, $curr_list);
     my ($added, $remained2, $new_names)   = $self->check_presence($curr_list, $reuse_list);

     my $dnafrags_differ = $added || $removed;
     if($dnafrags_differ) {
	 if ($self->debug) {
	     foreach my $dnafrag (keys %$old_names) {
		 print "UPDATE dnafrag SET name = '" . $new_names->{$dnafrag} . "' WHERE name='" . $old_names->{$dnafrag} . "';\n";
		 print "UPDATE member SET chr_name = '" . $new_names->{$dnafrag} . "' WHERE chr_name='" . $old_names->{$dnafrag} . "';\n";
	     }
	 }
	 $self->input_job->transient_error(0); 
	 die "The dnafrags changed: $added dnafrags were added and $removed were removed. Try running with debug to find which.\n";
    } else {
        warn "No change\n";
    }
 }

sub check_presence {
    my ($self, $from_dnafrags, $to_dnafrags) = @_;

    my @presence = (0, 0);

    my $extra_names;
    my $diffs;
    foreach my $dnafrag_id (keys %$from_dnafrags) {
	foreach my $name (keys %{$from_dnafrags->{$dnafrag_id}}) {
	    foreach my $length (keys %{$from_dnafrags->{$dnafrag_id}{$name}}) {
		foreach my $coord_system_name (keys %{$from_dnafrags->{$dnafrag_id}{$name}{$length}}) {
		    $presence[ exists($to_dnafrags->{$dnafrag_id}{$name}{$length}{$coord_system_name}) ? 1 : 0 ]++;
		    if ($self->debug) {
			unless (exists ($to_dnafrags->{$dnafrag_id}{$name}{$length}{$coord_system_name})) {
			    #print "Missing $dnafrag_id $name $length $coord_system_name \n";
			    $extra_names->{$dnafrag_id} = $name;
			}
		    }
		}
	    }
	}
    }
    return @presence, $extra_names;
}

return 1;
