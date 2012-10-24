
=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtEntries

=head1 DESCRIPTION

This object uses 'pfetch' or 'mfetch' (selectable) to fetch Uniprot sequence entries and stores them as members.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtEntries;

use strict;

use Bio::SeqIO;
use Bio::EnsEMBL::Compara::Member;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'uniprot_version'   => 'uniprot',   # you can also ask for a specific version of uniprot that mfetch would recognize
        'genome_db_id'      => undef,       # a constant to set all members to (YOU MUST KNOW THAT YOU'RE DOING!)
        'accession_number'  => 1,           # members get their stable_ids from seq->accession_number rather than $seq->display_id
        'seq_loader_name'   => 'pfetch',    # you can choose between 'mfetch' and 'pfetch'
        'min_length'        => 80,          # we don't want to load sequences that are shorter than this (set to 0 to switch off)
    };
}

sub fetch_input {
    my $self = shift @_;

    my %internal_taxon_ids = ();
    foreach my $genome_db (@{$self->compara_dba()->get_GenomeDBAdaptor->fetch_all}) {
        $internal_taxon_ids{$genome_db->taxon_id} = 1;
    }
    $self->param('internal_taxon_ids', \%internal_taxon_ids);
}

sub run {
    my $self = shift @_;

    my $uniprot_source  = $self->param('uniprot_source') or die "'uniprot_source' is an obligatory parameter and has to be defined";
    my $source_name = 'Uniprot/'.$uniprot_source;
    my $ids         = $self->param('ids');

    my @not_yet_stored_ids = ();
  
    foreach my $id (@$ids) {
        my $stable_id = ($id =~ /^(\S+)\.\d+$/) ? $1 : $id;     # drop the version number if it's there
        my $member = $self->compara_dba()->get_MemberAdaptor->fetch_by_source_stable_id($source_name, $stable_id);

        unless($member and $member->sequence_id) {  # skip the ones that have been already loaded
            push @not_yet_stored_ids, $id;
        }
    }
    $self->param('member_ids', $self->fetch_and_store_a_chunk($source_name, join(' ',@not_yet_stored_ids), scalar @not_yet_stored_ids) );
}


######################################
#
# subroutines
#
#####################################

sub fetch_and_store_a_chunk {
    my ($self, $source_name, $id_string, $total_in_this_batch) = @_;

    my $seq_loader_name = $self->param('seq_loader_name');
    my $uniprot_version = $self->param('uniprot_version');

    my @member_ids = ();

    my $seq_loader_cmd = { 'mfetch' => "mfetch -d $uniprot_version", 'pfetch' => 'pfetch -F' }->{$seq_loader_name};
    my $cmd = "$seq_loader_cmd $id_string |";


    ## would be great to detect here the case of mole server being down, but it's tricky to peek into the stream parser
  open(IN, $cmd) or die "Error running $seq_loader_name for ids ($id_string)";

  my $fh = Bio::SeqIO->new(-fh=>\*IN, -format=>"swiss");
  my $loaded_in_this_batch = 0;
  my $seen_in_this_batch = 0;

  while (my $seq = $fh->next_seq){
    $seen_in_this_batch++;

    next if ($seq->length < $self->param('min_length'));

    my $ncbi_taxon_id = $seq->species && $seq->species->ncbi_taxid;

    my $taxon = $self->compara_dba()->get_NCBITaxonAdaptor->fetch_node_by_taxon_id($ncbi_taxon_id);
    if($taxon) {
        $ncbi_taxon_id = $taxon->dbID;  # could have changed because of merged taxa
    } else { # if taxon has not been loaded into compara at all, do not store the member and warn:
        warn "Taxon id $ncbi_taxon_id from $source_name ". $seq->accession_number ." not in the database. Member not stored.";
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

    if(my $member_id = $self->store_bioseq($seq, $source_name, $ncbi_taxon_id)) {
        print STDERR "adding member $member_id\n";
        push @member_ids, $member_id;
        $loaded_in_this_batch++;
    } else {
        print STDERR "not adding member\n";
    }
  }
  close IN;
  if ($self->debug and ($loaded_in_this_batch<$seen_in_this_batch or $seen_in_this_batch<$total_in_this_batch)) {
    print "Expected $total_in_this_batch seqs but seen only $seen_in_this_batch and loaded $loaded_in_this_batch from ($id_string)\n";
  }

  return \@member_ids;
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
    $member->description( parse_description($bioseq->desc) );
    $member->source_name($source_name);
    $member->sequence($bioseq->seq);
    $member->genome_db_id($self->param('genome_db_id')) if($self->param('genome_db_id'));

    return $self->compara_dba()->get_MemberAdaptor->store($member);
}

sub parse_description {
    my $old_desc = shift @_;

    my @top_parts = split(/(?!\[\s*)(Includes|Contains):/,$old_desc);
    unshift @top_parts, '';

    my ($name, $desc, $flags, $top_prefix, $prev_top_prefix) = (('') x 3);
    while(@top_parts) {
        $prev_top_prefix = $top_prefix;
        $top_prefix      = shift @top_parts;

        if($top_prefix) {
            if($top_prefix eq $prev_top_prefix) {
                $desc .='; ';
            } else {
                if($prev_top_prefix) {
                    $desc .=']';
                }
                $desc .= "[$top_prefix ";
            }
        }
        my $top_data         = shift @top_parts;
        
        if($top_data=~/^\s*\w+:/) {
            my @parts = split(/(RecName|SubName|AltName|Flags):/, $top_data);
            shift @parts;
            while(@parts) {
                my $prefix = shift @parts;
                my $data   = shift @parts;

                if($prefix eq 'Flags') {
                    $data=~/^(.*?);/;
                    $flags .= $1;
                } else {
                    while($data=~/(\w+)\=([^\[;]*?(?:\[[^\]]*?\])?[^\[;]*?);/g) {
                        my($subprefix,$subdata) = ($1,$2);
                        if($subprefix eq 'Full') {
                            if($prefix eq 'RecName') {
                                if($top_prefix) {
                                    $desc .= $subdata;
                                } else {
                                    $name .= $subdata;
                                }
                            } elsif($prefix eq 'SubName') {
                                $name .= $subdata;
                            } elsif($prefix eq 'AltName') {
                                $desc .= "($subdata)";
                            }
                        } elsif($subprefix eq 'Short') {
                            $desc .= "($subdata)";
                        } elsif($subprefix eq 'EC') {
                            $desc .= "(EC $subdata)";
                        } elsif($subprefix eq 'Allergen') {
                            $desc .= "(Allergen $subdata)";
                        } elsif($subprefix eq 'INN') {
                            $desc .= "($subdata)";
                        } elsif($subprefix eq 'Biotech') {
                            $desc .= "($subdata)";
                        } elsif($subprefix eq 'CD_antigen') {
                            $desc .= "($subdata antigen)";
                        }
                    }
                }
            }
        } else {
            $desc .= $top_data; # This is to save the names that do not follow the pattern.
                                # Uniprot curators [should want to] thank us very much for this!
        }
    }
    if($top_prefix) {
        $desc .= ']';
    }

    return $name . $flags . $desc;
}

1;

