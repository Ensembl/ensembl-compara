
=pod 

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::CreateChrJobs

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB module generates DumpMultiAlign jobs from genomic_align_blocks
on the species chromosomes. The jobs are split into $split_size chunks

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateChrJobs;

use strict;
use Bio::EnsEMBL::Hive::DBSQL::AnalysisDataAdaptor;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;

use POSIX qw(ceil);

=head2 strict_hash_format

    Description : Implements strict_hash_format() interface method of Bio::EnsEMBL::Hive::Process that is used to set the strictness level of the parameters' parser.
                  Here we return 0 in order to indicate that neither input_id() nor parameters() is required to contain a hash.

=cut

sub strict_hash_format {
    return 0;
}

sub fetch_input {
    my $self = shift;
}

sub run {
    my $self = shift;


}

sub write_output {
    my $self = shift @_;

    my $output_ids;
    my $compara_dba;

    #
    #Load registry and get compara database adaptor
    #
    if ($self->param('reg_conf')) {
	Bio::EnsEMBL::Registry->load_all($self->param('reg_conf'),1);
	$compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($self->param('compara_dbname'), "compara");
    } elsif ($self->param('compara_url')) {
	#If define compara_url, must also define core_url(s)
	Bio::EnsEMBL::Registry->load_registry_from_url($self->param('compara_url'));
	if (!defined($self->param('core_url'))) {
	    throw("Must define core_url if define compara_url");
	}
	my @core_urls = split ",", $self->param('core_url');

	foreach my $core_url (@core_urls) {
	    Bio::EnsEMBL::Registry->load_registry_from_url($self->param('core_url'));
	}
	$compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$self->param('compara_url'));    
    } else {
	Bio::EnsEMBL::Registry->load_all();
	$compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($self->param('compara_dbname'), "compara");    
    }
    


    #
    #Find chromosome names and numbers of genomic_align_blocks
    #
    my $sql = qq {
    SELECT
       name,
       count(*)
    FROM
       dnafrag,
       genomic_align
    WHERE 
       dnafrag.dnafrag_id = genomic_align.dnafrag_id 
    AND 
       genome_db_id = ? 
    AND 
       coord_system_name = \"chromosome\" 
    AND 
       method_link_species_set_id = ? 
    GROUP BY name};

    my $sth = $compara_dba->dbc->prepare($sql);
    $sth->execute($self->param('genome_db_id'), $self->param('mlss_id'));
    my ($name, $total_blocks);
    $sth->bind_columns(\$name,\$total_blocks);

    my $chr_blocks; 
    my $tag = "chr";

    my $dump_program = $self->param('dump_program');
    my $dump_mlss_id = $self->param('dump_mlss_id');
    my $reg_conf = $self->param('reg_conf');
    my $compara_dbname = $self->param('compara_dbname');
    my $compara_url = $self->param('compara_url');
    my $masked_seq = $self->param('masked_seq');
    my $split_size = $self->param('split_size');
    my $format = $self->param('format');
    my $emf2maf_program = $self->param('emf2maf_program');
    my $maf_output_dir = $self->param('maf_output_dir');
    my $species = $self->param('species');

    if (defined($compara_url)) {
	#need to protect the @
	$compara_url =~ s/@/\\\\@/;
    }

    while (my $row = $sth->fetchrow_arrayref) {
	my $output_file = $self->param('output_dir') ."/" . $self->param('filename') . "." . $tag . $name . "." . $self->param('format');
	
	#print "output_file $output_file\n";

	my $num_chunks = ceil($total_blocks/$self->param('split_size'));
	#print "$name $total_blocks $num_chunks\n";

	#store chromosome name and number of chunks
	$chr_blocks->{$name} = $num_chunks;
	for (my $chunk = 1; $chunk <= $num_chunks; $chunk++) {

	    #Number of gabs in this chunk (used for healthcheck)
	    my $this_num_blocks = $split_size;
	    if ($chunk == $num_chunks) {
		$this_num_blocks = ($total_blocks - (($chunk-1)*$split_size));
	    }
	    #print "this_num_chunks $this_num_blocks\n";

	    my $this_suffix = "_" . $chunk . "." . $format;
	    my $dump_output_file = $output_file;
	    $dump_output_file =~ s/\.$format$/$this_suffix/;

	    #Write out cmd from DumpMultiAlign and a few other parameters 
	    #used in downstream analyses 
	    my $output_ids;
	    if ($reg_conf) {
		$output_ids = "{\"cmd\"=>\"perl $dump_program --reg_conf $reg_conf --dbname $compara_dbname --species $species --mlss_id $dump_mlss_id --seq_region $name --masked_seq $masked_seq --split_size $split_size --output_format $format --output_file $output_file --chunk_num $chunk\", \"num_blocks\"=>\"$this_num_blocks\", \"output_file\"=>\"$dump_output_file\", \"format\"=> \"$format\", \"emf2maf_program\"=>\"$emf2maf_program\", \"maf_output_dir\"=>\"$maf_output_dir\"}";
	    } else {
		$output_ids = "{\"cmd\"=>\"perl $dump_program --db $compara_url --species $species --mlss_id $dump_mlss_id --seq_region $name --masked_seq $masked_seq --split_size $split_size --output_format $format --output_file $output_file --chunk_num $chunk\", \"num_blocks\"=>\"$this_num_blocks\", \"output_file\"=>\"$dump_output_file\", \"format\"=> \"$format\", \"emf2maf_program\"=>\"$emf2maf_program\", \"maf_output_dir\"=>\"$maf_output_dir\"}";
	    }
	    #print "$output_ids\n";
	    
	    $self->dataflow_output_id($output_ids, 2);
	}
    }



}

1;
