=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtEntries

=head1 DESCRIPTION

This object uses 'pfetch' or 'mfetch' (selectable) to fetch Uniprot sequence entries and stores them as members.
Alternatively, the module can load a whole file by setting "seq_loader_name" to 'file'.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtEntries;

use strict;
use warnings;
use Bio::Perl;
BEGIN {         # Because BioPerl switched from not recordin version to 1.4 to 1.5 to 1.00500x format
                # we cannot simply rely on Perl to correctly require the version we need
                # and have to carefully work around this childish outburst.
    die "This module now requires Bio::Perl::VERSION to be at least 1.6.0; Your current BioPerl version is ".($Bio::Perl::VERSION || '(undef)').", please check your PERL5LIB.\n"
        if(!defined($Bio::Perl::VERSION)    # not defined prior to 1.4.0
        or $Bio::Perl::VERSION >= 1.1       # defined but in old format since 1.4.0
        or $Bio::Perl::VERSION<1.006);      # we require at least 1.6.0
}

use Bio::SeqIO;

use Bio::EnsEMBL::Compara::SeqMember;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'uniprot_version'   => 'uniprot',   # you can also ask for a specific version of uniprot that mfetch would recognize
        'genome_db_id'      => undef,       # a constant to set all members to (YOU MUST KNOW THAT YOU'RE DOING!)
        'accession_number'  => 1,           # members get their stable_ids from seq->accession_number rather than $seq->display_id
        'seq_loader_name'   => 'pfetch',    # you can choose between 'mfetch', 'pfetch' and 'file'
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

    my $uniprot_source  = $self->param_required('uniprot_source');
    my $source_name = 'Uniprot/'.$uniprot_source;

    if ($self->param('seq_loader_name') eq 'file') {
        $source_name = { 'sprot' => 'Uniprot/SWISSPROT', 'trembl' => 'Uniprot/SPTREMBL' }->{$uniprot_source};
        $self->param('member_ids', $self->fetch_and_store_a_chunk($source_name, $self->param_required('uniprot_file'), $self->param_required('file_size')));
        return;
    }

    my $ids         = $self->param('ids');

    my @not_yet_stored_ids = ();
  
    foreach my $id (@$ids) {
        my $stable_id = ($id =~ /^(\S+)\.\d+$/) ? $1 : $id;     # drop the version number if it's there
        my $seq_member = $self->compara_dba()->get_SeqMemberAdaptor->fetch_by_stable_id($stable_id);
        my $seq_member_id;

        if($seq_member and $seq_member_id = $seq_member->seq_member_id) {
            print "Member '$stable_id' already stored (seq_member_id=$seq_member_id), skipping\n";
        } else {    # skip the ones that have been already stored
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

    my $seq_loader_cmd = { 'mfetch' => "mfetch -d $uniprot_version", 'pfetch' => 'pfetch -F', 'file' => 'cat ' }->{$seq_loader_name};
    my $cmd = "$seq_loader_cmd $id_string |";


    ## would be great to detect here the case of mole server being down, but it's tricky to peek into the stream parser
  open(IN, $cmd) or die "Error running $seq_loader_name for ids ($id_string)";

  my $fh = Bio::SeqIO->new(-fh=>\*IN, -format=>"swiss");
  my $loaded_in_this_batch = 0;
  my $seen_in_this_batch = 0;

  while (my $seq = $fh->next_seq){

    my $member_name = $source_name.'/'.( $self->param('accession_number') ? $seq->accession_number : $seq->display_id );
    $seen_in_this_batch++;

    if ($seq->length < $self->param('min_length')) {
        print STDERR "Member '$member_name' not loaded because it is shorter (".$seq->length.") than current cutoff of ".$self->param('min_length')."\n";
        next;
    }

    my $ncbi_taxon_id = $seq->species && $seq->species->ncbi_taxid;

    my $taxon = $self->compara_dba()->get_NCBITaxonAdaptor->fetch_node_by_taxon_id($ncbi_taxon_id);
    if($taxon) {
        $ncbi_taxon_id = $taxon->dbID;  # could have changed because of merged taxa
    } else { # if taxon has not been loaded into compara at all, do not store the member and warn:
        print STDERR "Member '$member_name' not loaded because taxon_id $ncbi_taxon_id is not in the database.\n";
        next;
    }

    ########################################################################################################
    # This bit is to avoid duplicated entries btw Ensembl and Uniprot.
    # Has been re-written based on new (v1.6 and later) BioPerl functionality instead of homebrew patches.
    #
    if ($self->param('internal_taxon_ids')->{$ncbi_taxon_id}) {
        if(my ($evidence_annotations) = $seq->annotation->get_Annotations('evidence')) {
            my $evidence_value = $evidence_annotations->value;

            if ($evidence_value =~ /^4/) {
                print STDERR "Member '$member_name' not loaded from Uniprot as it should be already loaded from EnsEMBL (evidence_value = '$evidence_value').\n";
                next;
            }
        }
    }
    #
    ########################################################################################################

    if(my $seq_member_id = $self->store_bioseq($seq, $source_name, $ncbi_taxon_id)) {
        print STDERR "Member '$member_name' stored under seq_member_id=$seq_member_id\n";
        push @member_ids, $seq_member_id;
        $loaded_in_this_batch++;
    } else {
        print STDERR "Member '$member_name' not stored.\n";
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
        printf("store_bioseq %s %s : %d : %s\n", $source_name, $bioseq->display_id, $ncbi_taxon_id, $species_name);
    }
   
    my $member = new Bio::EnsEMBL::Compara::SeqMember(
        -stable_id      => $self->param('accession_number') ? $bioseq->accession_number : $bioseq->display_id,
        -taxon_id       => $ncbi_taxon_id,
        -description    => parse_description($bioseq->desc),
        -source_name    => $source_name,
    );
    $member->display_label($bioseq->display_id);
    $member->sequence($bioseq->seq);
    $member->genome_db_id($self->param('genome_db_id')) if($self->param('genome_db_id'));

    return $self->compara_dba()->get_SeqMemberAdaptor->store($member);
}


sub parse_description {
    my $old_desc = shift @_;

    my @top_parts = split(/(?!\[\s*)(Includes|Contains):/,$old_desc);
    unshift @top_parts, '';

    my %seen_evidences = ();

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
                        if ($subdata =~ /({.*})/) {
                            if ($seen_evidences{$1}) {
                                $subdata =~ s/ *{.*}//;
                            } else {
                                $seen_evidences{$1} = 1;
                            }
                        }
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
                                $desc .= " ($subdata)";
                            }
                        } elsif($subprefix eq 'Short') {
                            $desc .= " ($subdata)";
                        } elsif($subprefix eq 'EC') {
                            $desc .= " (EC $subdata)";
                        } elsif($subprefix eq 'Allergen') {
                            $desc .= " (Allergen $subdata)";
                        } elsif($subprefix eq 'INN') {
                            $desc .= " ($subdata)";
                        } elsif($subprefix eq 'Biotech') {
                            $desc .= " ($subdata)";
                        } elsif($subprefix eq 'CD_antigen') {
                            $desc .= " ($subdata antigen)";
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

