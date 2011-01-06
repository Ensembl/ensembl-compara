#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProt

=cut

=head1 DESCRIPTION

This object uses the mfetch to get the list of Uniprot accession numbers
and pfetch or mfetch (selectable) to actually fetch the sequence entries.

Its purpose is to load protein sequences from Uniprot into the compara database.

The format of the input_id follows the format of a Perl hash reference.
Examples:
  "{'srs' => 'SWISSPROT', taxon_id=>4932}"      # loads all SwissProt for S.cerevisiae
  "{'srs' => 'SPTREMBL'}"                       # loads all SPTrEMBL Fungi/Metazoa
  "{'srs' => 'SPTREMBL', taxon_id=>4932}"       # loads all SPTrEMBL for S.cerevisiae
  "{'srs' => 'SWISSPROT', 'tax_div' => 'FUN'}"  # loads all SwissProt fungi proteins
  "{'srs' => 'SPTREMBL',  'tax_div' => 'ROD'}"  # loads all SwissProt rodent proteins

supported keys:
  srs => valid values: 'SWISSPROT', 'SPTREMBL'
  taxon_id => <taxon_id>
       optional if one want to load from a specific species
       if not specified it will load all Fungi/Metazoa from the srs source
  genome_db_id => <genome_db_id>
       optional: will associate this loaded set into the specified 
       GenomeDB does not create genome_db entry, assumes it was already 
       created.  Use prudently since it does no checks
  accession_number => 0/1 (default is 1=on)
       optional: if one wants to load Accession Number (AC) (DEFAULT) as 
       stable_id rather than Entry Name (ID) 

=cut

=head1 CONTACT

  Contact Jessica Severin on LoadUniprot implemetation/design detail: jessica@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL::Compara in general: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProt;

use strict;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Subset;
use Bio::SeqIO;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'uniprot'           => 'uniprot',   # but you can ask for a specific version of uniprot that mfetch would recognize
        'srs'               => 'SWISSPROT', # either 'SWISSPROT' or 'SPTREMBL'
        'taxon_id'          => undef,       # no ncbi_taxid filter means get all Fungi/Metazoa
        'genome_db_id'      => undef,       # a constant to set all members to (YOU MUST KNOW THAT YOU'RE DOING!)
        'accession_number'  => 1,           # members get their stable_ids from seq->accession_number rather than $seq->display_id
        'buffer_size'       => 30,          # how many uniprot_ids are fetched per one execution of mfetch
        'tax_div'           => undef,       # metazoa can be split into 6 parts and loaded in parallel
        'seq_loader_name'   => 'mfetch',    # you can choose between 'mfetch' and 'pfetch'
        'min_length'        => 80,          # we don't want to load sequences that are shorter than this (set to 0 to switch off)
    };
}

sub fetch_input {
    my $self = shift @_;

    $self->compara_dba()->dbc->disconnect_when_inactive(0);

    my %internal_taxon_ids = ();
    foreach my $genome_db (@{$self->compara_dba()->get_GenomeDBAdaptor->fetch_all}) {
        $internal_taxon_ids{$genome_db->taxon_id} = 1;
    }
    $self->param('internal_taxon_ids', \%internal_taxon_ids);
    
    my $subset_name = $self->param('srs');
    if(my $taxon_id = $self->param('taxon_id')) {
        $subset_name .= " ncbi_taxid:$taxon_id";
        $self->param('uniprot_ids', $self->mfetch_uniprot_ids($self->param('uniprot'), $self->param('srs'), $taxon_id) );
    } else {
        my $tax_div = $self->param('tax_div');
        $subset_name .= " metazoa";
        $subset_name .= ", tax_div:$tax_div" if($tax_div);
        $self->param('uniprot_ids', $self->mfetch_uniprot_ids($self->param('uniprot'), $self->param('srs'),'', $tax_div && [ $tax_div ]) );
    }

    my $subset_adaptor = $self->compara_dba()->get_SubsetAdaptor();
    my $subset;
    unless($subset = $subset_adaptor->fetch_by_set_description($subset_name)) {
        $subset = Bio::EnsEMBL::Compara::Subset->new(-name=>$subset_name);
        $subset_adaptor->store($subset);
    }
    $self->param('subset', $subset);

    $self->param('source_name', 'Uniprot/'.$self->param('srs'));
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
}

sub write_output {  
    my $self = shift;

    my %output_hash = (
        'ss' => $self->param('subset')->dbID,
        ($self->param('genome_db_id')
            ? ( 'genome_db_id' => $self->param('genome_db_id') )
            : ()
        ),
    );
    $self->dataflow_output_id( \%output_hash , 2);
}


######################################
#
# subroutines
#
#####################################

sub mfetch_uniprot_ids {
    my $self     = shift;
    my $uniprot  = shift;  # 'uniprot' or a specific version of it
    my $source   = shift;  # 'SWISSPROT' or 'SPTREMBL'
    my $taxon_id = shift;  # assume Fungi/Metazoa if not set
    my $tax_divs = shift || [ $taxon_id ? 0 : qw(FUN HUM MAM ROD VRT INV) ];

    my @filters = ( 'div:'.(($source=~/sptrembl/i) ? 'PRE' : 'STD') );
    if($taxon_id) {
        push @filters, "txi:$taxon_id";
    } else {
        push @filters, "txt:33154"; # anything that belongs to Fungi/Metazoa subtree (clade)
    }

    my @all_ids = ();
    foreach my $txd (@$tax_divs) {
        my $cmd = "mfetch -d $uniprot -v av -i '".join('&', @filters).($txd ? "&txd:$txd" : '')."'";
        print("$cmd\n") if($self->debug);
        if( my $output_text = `$cmd` ) {
            my @ids = split(/\s/, $output_text);
            push @all_ids, @ids;
        } else {
            die "[$cmd] returned nothing, mole server probably down";
        }
    }
    printf("fetched %d ids from %s\n", scalar(@all_ids), $source) if($self->debug);
    return \@all_ids;
}

sub fetch_and_store_a_chunk {
    my ($self, $source_name, $id_string, $total_in_this_batch) = @_;

    my $seq_loader_name = $self->param('seq_loader_name');
    my $seq_loader_cmd = { 'mfetch' => 'mfetch -d uniprot', 'pfetch' => 'pfetch -F' }->{$seq_loader_name};

    ## would be great to detect here the case of mole server being down, but it's tricky to peek into the stream parser
  open(IN, "$seq_loader_cmd $id_string |") or $self->throw("Error running $seq_loader_name for ids ($id_string)");

  print STDERR "$id_string\n";
  my $fh = Bio::SeqIO->new(-fh=>\*IN, -format=>"swiss");
  my $loaded_in_this_batch = 0;
  my $seen_in_this_batch = 0;
  while (my $seq = $fh->next_seq){
    $seen_in_this_batch++;
    next if ($seq->length < $self->param('min_length'));

    my $ncbi_taxon_id = $seq->species && $seq->species->ncbi_taxid;

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
    $member->description( parse_description($bioseq->desc) );
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

