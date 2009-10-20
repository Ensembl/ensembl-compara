#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::LoadUniProt

=cut

=head1 DESCRIPTION

This object uses the getz and pfetch command line programs to access
the SRS database of Uniprot sequences.
Its purpose is to load protein sequences from Uniprot into the compara 
database.
Right now it has hard coded filters of a minimum sequence length of 80
and taxon in metazoa and distinguishes SWISSPROT from SPTREMBL.

The format of the input_id follows the format of a Perl hash reference.
Examples:
  "{srs=>'swissprot', taxon_id=>4932}" # loads all swissprot for S.cerevisiae
  "{srs=>'sptrembl'}"                  # loads all sptrembl metazoa
  "{srs=>'sptrembl', taxon_id=>4932}"  # loads all sptrembl for S.cerevisiae

supported keys:
  srs => valid values: 'SWISSPROT', 'SPTREMBL'
  taxon_id => <taxon_id>
       optional if one want to load from a specific species
       if not specified it will load all 'metazoa' from the srs source
  genome_db_id => <genome_db_id>
       optional: will associate this loaded set into the specified 
       GenomeDB does not create genome_db entry, assumes it was already 
       created.  Use prudently since it does no checks
  accession_number => 0/1 (default is 1=on)
       optional: if one wants to load Accession Number (AC) (DEFAULT) as 
       stable_id rather than Entry Name (ID) 
  id_start_from => <numerical_id>
        optional: start loading members from the given id (to create distinct ranges)

=cut

=head1 CONTACT

  Contact Jessica Severin on LoadUniprot implemetation/design detail: jessica@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL::Compara in general: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

package Bio::EnsEMBL::Compara::RunnableDB::LoadUniProt;

use strict;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Subset;
use Bio::SeqIO;

use base ('Bio::EnsEMBL::Hive::ProcessWithParams');

    # This should really be in the superclass of all Compara::RunnableDB's!
sub compara_dba {
    my $self = shift @_;

    return $self->{'comparaDBA'} ||= Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
}

sub fetch_input {
    my $self = shift @_;

    $self->debug(0);

    $self->param_init(  # these defaults take the lowest priority after input_id and parameters
        'srs'               => 'SWISSPROT',
        'taxon_id'          => undef,   # no ncbi_taxid filter, get all metzoa
        'genome_db_id'      => undef,
        'accession_number'  => 1,       # members get their stable_ids from seq->accession_number rather than $seq->display_id
        'buffer_size'       => 30,      # how many uniprot_ids are fetched per one execution of mfetch
        'tax_div'           => undef,   # metazoa can be split into 6 parts and loaded in parallel
    );

    $self->compara_dba()->dbc->disconnect_when_inactive(0);

    my %internal_taxon_ids = ();
    foreach my $genome_db (@{$self->compara_dba()->get_GenomeDBAdaptor->fetch_all}) {
        $internal_taxon_ids{$genome_db->taxon_id} = 1;
    }
    $self->param('internal_taxon_ids', \%internal_taxon_ids);
    
    my $subset_name = $self->param('srs');
    my $taxon_id    = $self->param('taxon_id');
    my %allowed_taxon_ids = ();
    if($taxon_id) {
        $subset_name .= " ncbi_taxid:$taxon_id";
        $allowed_taxon_ids{$taxon_id} = 1;
        $self->param('uniprot_ids', $self->mfetch_uniprot_ids($self->param('srs'), $taxon_id) );
    } else {
        my $tax_div = $self->param('tax_div');
        $subset_name .= " metazoa";
        $subset_name .= ", tax_div:$tax_div" if($tax_div);
        $self->param('uniprot_ids', $self->mfetch_uniprot_ids($self->param('srs'),'', $tax_div && [ $tax_div ]) );

        # Fungi/Metazoa group
        $taxon_id = 33154;
        my $node = $self->compara_dba()->get_NCBITaxonAdaptor->fetch_node_by_taxon_id($taxon_id);

                # The following loop is the performance curse of the whole module.
                # Every execution spends 20-30 minutes loading the leaves.
                # It would be great if it could be (internally?) optimized.
                #
        #foreach my $leaf ( @{$node->get_all_leaves} ) {
        foreach my $leaf ( @{$node->get_all_leaves_indexed} ) {
            # the indexed method should be much faster when data has left and right indexes built
            $allowed_taxon_ids{$leaf->node_id} = 1;
            if ($leaf->rank ne 'species') {
                $allowed_taxon_ids{$leaf->parent->node_id} = 1;
            }
        }
        $node->release_tree;
    }
    $self->param('allowed_taxon_ids', \%allowed_taxon_ids);

    my $subset_adaptor = $self->compara_dba()->get_SubsetAdaptor();
    my $subset;
    unless($subset = $subset_adaptor->fetch_by_set_description($subset_name)) {
        $subset = Bio::EnsEMBL::Compara::Subset->new(-name=>$subset_name);
        $subset_adaptor->store($subset);
    }
    $self->param('subset', $subset);

    $self->param('source_name', 'Uniprot/'.$self->param('srs'));

    return 1;
}

sub run {
    my $self = shift @_;

    my $source_name = $self->param('source_name');
    my $uniprot_ids = $self->param('uniprot_ids');
    my $buffer_size = $self->param('buffer_size');
  
    my @id_chunk = ();
    my $total  = scalar(@$uniprot_ids);
    my $index  = 0;
    my $loaded = 0;
  
    if($self->param('id_start_from')) {
        $self->set_id_auto_increment();
    }

    foreach my $id (@$uniprot_ids) {
        $index++;
        print("checked/loaded $index ids so far\n") if($index % 100 == 0 and $self->debug);

        my $stable_id = ($id =~ /^(\S+)\.\d+$/) ? $1 : $id;     # drop the version number if it's there
        my $member = $self->compara_dba()->get_MemberAdaptor->fetch_by_source_stable_id($source_name, $stable_id);

        unless($member and $member->sequence_id) {  # skip the ones that have been already loaded
            push @id_chunk, $id;
            $loaded++;
        }

        if(scalar(@id_chunk)>=$buffer_size) { # flush the buffer
            $self->fetch_and_store_a_chunk($source_name, join(' ',@id_chunk), scalar @id_chunk);
            @id_chunk = ();
        }
    }

    if(scalar(@id_chunk)) { # flush the rest
        $self->fetch_and_store_a_chunk($source_name, join(' ',@id_chunk), scalar @id_chunk);
    }

    if($self->debug()) {
        print "Went through $total ids from '$source_name', of which $loaded needed to be loaded into the database\n";
    }
    return 1;
}

sub write_output {  
    my $self = shift;

    my $outputHash = {};
    $outputHash = eval($self->input_id) if(defined($self->input_id));
    $outputHash->{'ss'}  = $self->param('subset')->dbID;
    $outputHash->{'gdb'} = $self->param('genome_db_id') if($self->param('genome_db_id'));
    my $output_id = $self->encode_hash($outputHash);

    $self->input_job->input_id($output_id);

    if($self->param('genome_db_id')) {
        $self->dataflow_output_id($output_id, 2);
    }
    return 1;
}


######################################
#
# subroutines
#
#####################################

sub mfetch_uniprot_ids {
    my $self     = shift;
    my $source   = shift;  # 'swissprot' or 'sptrembl'
    my $taxon_id = shift;  # assume Fungi/Metazoa if not set
    my $tax_divs = shift || [ $taxon_id ? 0 : qw(FUN HUM MAM ROD VRT INV) ];

    my @filters = ( 'div:'.(($source=~/sptrembl/i) ? 'PRE' : 'STD') );
    if($taxon_id) {
        push @filters, "txi:$taxon_id";
    }

    my @all_ids = ();
    foreach my $txd (@$tax_divs) {
        my $cmd = "mfetch -d uniprot -v av -i '".join('&', @filters).($txd ? "&txd:$txd" : '')."'";
        print("$cmd\n") if($self->debug);
        if( my $output_text = `$cmd` ) {
            my @ids = split(/\s/, $output_text);
            push @all_ids, @ids;
        } else {
            die "mfetch returned nothing, mole server probably down";
        }
    }
    printf("fetched %d ids from %s\n", scalar(@all_ids), $source) if($self->debug);
    return \@all_ids;
}

sub fetch_and_store_a_chunk {
    my ($self, $source_name, $id_string, $total_in_this_batch) = @_;

    ## would be great to detect here the case of mole server being down, but it's tricky to peek into the stream parser
  open(IN, "mfetch -d uniprot $id_string |") or $self->throw("Error running mfetch for ids ($id_string)");

  print STDERR "$id_string\n";
  my $fh = Bio::SeqIO->new(-fh=>\*IN, -format=>"swiss");
  my $loaded_in_this_batch = 0;
  my $seen_in_this_batch = 0;
  while (my $seq = $fh->next_seq){
    $seen_in_this_batch++;
    next if ($seq->length < 80);

    my $ncbi_taxon_id = $seq->species && $seq->species->ncbi_taxid;
    unless ($self->param('allowed_taxon_ids')->{$ncbi_taxon_id}) { # this will also implicitly check for zero
        next;
    }

    ####################################################################
    # This bit is to avoid duplicated entries btw Ensembl and Uniprot
    # It only affects the Ensembl species dbs, and right now I am using
    # a home-brewed version of Bio::SeqIO::swiss to parse the PE entries
    # in a similar manner as comments (CC) but of type 'evidence'
    #
    # NB: To avoid severe disappointment make sure you actually have
    #     Abel's home-brewed version of bioperl-live in your PERL5LIB
    #
    #
    if ($self->param('internal_taxon_ids')->{$ncbi_taxon_id}) {
      my $evidence_annotations; 
      eval { $evidence_annotations = $seq->get_Annotations('evidence');}; # old style
      if ($@) {
        my $annotation = $seq->annotation;
        $evidence_annotations = $annotation->get_Annotations('evidence');
      }
      if (defined $evidence_annotations) {
            if ($evidence_annotations->text =~ /^4/) {
              print STDERR $seq->display_id, "PE discarded ", $evidence_annotations->text, "\n";
              next;      # We don't want duplicated entries
            }
      }
    }
    ####################################################################

        # if taxon is not loaded into compara, do not store the member and warn:
    unless(my $taxon = $self->compara_dba()->get_NCBITaxonAdaptor->fetch_node_by_taxon_id($ncbi_taxon_id)) {
        warning("Taxon id $ncbi_taxon_id from $source_name ". $seq->accession_number ." not in the database. Member not stored.");
        next;
    }

    if($self->store_bioseq($seq, $source_name, $ncbi_taxon_id)) {
        $loaded_in_this_batch++;
    }
  }
  close IN;
  if ($self->debug and ($loaded_in_this_batch<$seen_in_this_batch or $seen_in_this_batch<$total_in_this_batch)) {
    print "Expected $total_in_this_batch seqs but seen only $seen_in_this_batch and loaded $loaded_in_this_batch from ($id_string)\n";
  }
}

sub store_bioseq {
    my ($self, $bioseq, $source_name, $ncbi_taxon_id) = @_;

    if($self->debug) {
        my $species_name = $bioseq->species && $bioseq->species->species;
        printf("store_bioseq %s %s : %d : %s", $source_name, $bioseq->display_id, $ncbi_taxon_id, $species_name);
    }
   
    my $member = new Bio::EnsEMBL::Compara::Member;
    $member->stable_id( $self->param('accession_number') ? $bioseq->accession_number : $bioseq->display_id );
    $member->display_label($bioseq->display_id);
    $member->taxon_id($ncbi_taxon_id);
    $member->description($bioseq->desc);
    $member->source_name($source_name);
    $member->sequence($bioseq->seq);
    $member->genome_db_id($self->param('genome_db_id')) if($self->param('genome_db_id'));

    eval {
        $self->compara_dba()->get_MemberAdaptor->store($member);
        print(" --stored") if($self->debug);
        $self->param('subset')->add_member($member);
        print("\n") if($self->debug);
    };
    if ($@) {
        print(" --not stored: $@\n") if($self->debug);
        return 0;
    }
    return 1;
}

sub set_id_auto_increment { # increment the IDs of both member and sequence tables:
    my $self = shift @_;

    return if($self->param('auto_increment_been_here'));   # only perform this operation once

    if(my $id_start_from = $self->param('id_start_from') ) {

        for my $table_name ('member', 'sequence') {
                # should not use the '?'-syntax here to avoid implicit quotation of numeric argument:
            my $sql = "ALTER TABLE $table_name AUTO_INCREMENT=".($id_start_from+0);
            my $sth = $self->compara_dba()->dbc->prepare( $sql );
            $sth->execute();
        }
    }

    $self->param('auto_increment_been_here', 1);    # so that we never come here again (for any reason)
}

1;

