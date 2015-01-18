=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::LoadMembers

=cut

=head1 SYNOPSIS

        # load reference peptide+gene members of a particular genome_db (mouse)
    standaloneJob.pl LoadMembers.pm -compara_db "mysql://ensadmin:${ENSADMIN_PSW}@compara2/lg4_test_loadmembers" -genome_db_id 57

        # load nonreference peptide+gene members of a particular genome_db (human)
    standaloneJob.pl LoadMembers.pm -compara_db "mysql://ensadmin:${ENSADMIN_PSW}@compara2/lg4_test_loadmembers" -genome_db_id 90 -include_nonreference 1 -include_reference 0

        # load reference coding exon members of a particular genome_db (rat)
    standaloneJob.pl LoadMembers.pm -compara_db "mysql://ensadmin:${ENSADMIN_PSW}@compara2/lg4_test_loadmembers" -genome_db_id 3 -coding_exons 1 -min_length 20

=cut

=head1 DESCRIPTION

This RunnableDB works in two major modes, depending on the trueness of 'coding_exons' parameter.

ProteinTree pipeline uses this module with $self->param('coding_exons') set to false.
Which is a request to load peptide+gene members from a particular core database defined by $self->param('genome_db_id').

MercatorPecan pipeline uses this module with $self->param('coding_exons') set to true.
Which is a request to load coding exon members from a particular core database defined by $self->param('genome_db_id').

You can also choose whether you want your members (peptides or coding exons) extracted from reference slices, nonreference slices (including LRGs) or both
by using -include_reference <0|1> and -include_nonreference <0|1> parameters.

=cut

=head1 CONTACT

Contact anybody in Compara.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::LoadMembers;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::SeqMember;
use Bio::EnsEMBL::Compara::GeneMember;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'verbose'                       => undef,

            # which input Slices are used to load Members from:
        'include_reference'             => 1,
        'include_nonreference'          => 0,
        'include_patches'               => 0,
        'store_missing_dnafrags'        => 0,

        'coding_exons'                  => 0,   # switch between 'ProteinTree' mode and 'Mercator' mode

            # only in 'ProteinTree' mode:
        'store_genes'                   => 1,   # whether the genes are also stored as members
        'allow_ambiguity_codes'         => 0,
        'store_related_pep_sequences'   => 0,
        'pseudo_stableID_prefix'        => undef,
        'force_unique_canonical'        => undef,
        'find_canonical_translations_for_polymorphic_pseudogene' => 0,
    };
}


sub fetch_input {
    my $self = shift @_;

        # not sure if this can be done directly in param_defaults because of the order things get initialized:
    unless(defined($self->param('verbose'))) {
        $self->param('verbose', $self->debug == 2);
    }

    my $genome_db_id = $self->param_required('genome_db_id');

    my $compara_dba = $self->compara_dba();

        #get the Compara::GenomeDB object for the genome_db_id:
    my $genome_db = $self->param('genome_db', $compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) )
        or die "Can't fetch the genome_db object (gdb_id=$genome_db_id) from Compara";
  
        #using genome_db_id, connect to external core database:
    $self->param('core_dba', $genome_db->db_adaptor() )
        or die "Can't connect to external core database for gdb=$genome_db_id";

    unless($self->param('include_reference') or $self->param('include_nonreference')) {
        die "Either 'include_reference' or 'include_nonreference' or both have to be true";
    }
}


sub run {
    my $self = shift @_;

    my $compara_dba = $self->compara_dba();
    my $core_dba    = $self->param('core_dba');

    $compara_dba->dbc->disconnect_when_inactive(0);
    $core_dba->dbc->disconnect_when_inactive(0);

    my $unfiltered_slices = $self->param('genome_db')->genome_component
        ? $core_dba->get_SliceAdaptor->fetch_all_by_genome_component($self->param('genome_db')->genome_component)
        : $core_dba->get_SliceAdaptor->fetch_all('toplevel', $self->param('include_nonreference') ? (undef, 1, undef, 1) : ());
    die "Could not fetch any toplevel slices from ".$core_dba->dbc->dbname() unless(scalar(@$unfiltered_slices));

    my $slices = $self->param('include_reference')
                    ? $unfiltered_slices
                    : [ grep { not $_->is_reference() } @$unfiltered_slices ];

  my $final_slices = ( ! $self->param('include_patches') ) ?
                       [ grep { $_->assembly_exception_type() !~ /PATCH/ } @$slices ]
                       : [ @$slices ];

    if(scalar(@$final_slices)) {

        $self->loadMembersFromCoreSlices( $final_slices );

    } else {

        $self->warning("No suitable toplevel slices found in ".$core_dba->dbc->dbname());
    }
}

sub write_output {
    my $self = shift @_;

    $self->dataflow_output_id( {
        'genome_db_id'      => $self->param('genome_db_id'),
        'reuse_this'        => 0,
    } , 1);
}


######################################
#
# subroutines
#
#####################################


sub loadMembersFromCoreSlices {
    my ($self, $slices) = @_;

        # initialize internal counters for tracking success of process:
    $self->param('sliceCount',      0);
    $self->param('geneCount',       0);
    $self->param('realGeneCount',   0);
    $self->param('transcriptCount', 0);

  #from core database, get all slices, and then all genes in slice
  #and then all transcripts in gene to store as members in compara

  my @genes;

  foreach my $slice (@$slices) {
    $self->param('sliceCount', $self->param('sliceCount')+1 );
    #print("slice " . $slice->name . "\n");
    my $dnafrag = $self->compara_dba->get_DnaFragAdaptor->fetch_by_GenomeDB_and_name($self->param('genome_db'), $slice->seq_region_name);
    unless ($dnafrag) {
        if ($self->param('store_missing_dnafrags')) {
            $dnafrag = Bio::EnsEMBL::Compara::DnaFrag->new_from_Slice($slice, $self->param('genome_db'));
            $self->compara_dba->get_DnaFragAdaptor->store($dnafrag);
        } else {
            $self->throw(sprintf('Cannot find / create a DnaFrag with name "%s" for "%s"', $slice->seq_region_name, $self->param('genome_db')->name));
        }
    }

    @genes = ();
    my $current_end;

    foreach my $gene (sort {$a->start <=> $b->start} @{$slice->get_all_Genes(undef, undef, 1)}) {
      $self->param('geneCount', $self->param('geneCount')+1 );
      # LV and C are for the Ig/TcR family, which rearranges
      # somatically so is considered as a different biotype in EnsEMBL
      # D and J are very short or have no translation at all

      if ($self->param('coding_exons')) {
          $current_end = $gene->end unless (defined $current_end);
          if((lc($gene->biotype) eq 'protein_coding')) {
              $self->param('realGeneCount', $self->param('realGeneCount')+1 );
              if ($gene->start <= $current_end) {
                  push @genes, $gene;
                  $current_end = $gene->end if ($gene->end > $current_end);
              } else {
                  $self->store_all_coding_exons(\@genes, $dnafrag);
                  @genes = ();
                  $current_end = $gene->end;
                  push @genes, $gene;
              }
          }
      } else {
          if ( lc($gene->biotype) eq 'protein_coding'
               || lc($gene->biotype) =~ /ig_._gene/
               || lc($gene->biotype) =~ /tr_._gene/
               || lc($gene->biotype) eq 'polymorphic_pseudogene'     # mm14 says it is ok :)
               || lc($gene->biotype) eq 'lrg_gene'
             ) {
              $self->param('realGeneCount', $self->param('realGeneCount')+1 );
              
              $self->store_gene_and_all_transcripts($gene, $dnafrag);
              
              print STDERR $self->param('realGeneCount') , " genes stored\n" if ($self->debug && (0 == ($self->param('realGeneCount') % 100)));
          }
      }
    } # foreach

    if ($self->param('coding_exons')) {
        $self->store_all_coding_exons(\@genes, $dnafrag);
    }
  }

  print("loaded ".$self->param('sliceCount')." slices\n");
  print("       ".$self->param('geneCount')." genes\n");
  print("       ".$self->param('realGeneCount')." real genes\n");
  print("       ".$self->param('transcriptCount')." transcripts\n");
}


sub store_gene_and_all_transcripts {
    my $self = shift;
    my $gene = shift;
    my $dnafrag = shift;

    my $gene_member_adaptor = $self->compara_dba->get_GeneMemberAdaptor();
    my $seq_member_adaptor = $self->compara_dba->get_SeqMemberAdaptor();
    my $sequence_adaptor = $self->compara_dba->get_SequenceAdaptor();

    my $canonicalPeptideMember;
    my $gene_member;

    if(defined($self->param('pseudo_stableID_prefix'))) {
        $gene->stable_id($self->param('pseudo_stableID_prefix') ."G_". $gene->dbID);
    }

    my $canonical_transcript; my $canonical_transcript_stable_id;
    eval {
        $canonical_transcript = $gene->canonical_transcript;
        $canonical_transcript_stable_id = $canonical_transcript->stable_id;
    };
    if (!defined($canonical_transcript) && !defined($self->param('force_unique_canonical'))) {
        die $gene->stable_id." has no canonical transcript\n";
    }
    my $longestTranslation = undef;

    if (!defined($self->param('force_unique_canonical'))) {
        if ($canonical_transcript->biotype ne $gene->biotype) {
            # This can happen when the only transcripts are, e.g., NMDs
            $self->warning($canonical_transcript->stable_id." biotype ".$canonical_transcript->biotype." is canonical (gene is ".$gene->biotype.")");
        }
    }

    foreach my $transcript (@{$gene->get_all_Transcripts}) {
        my $translation = $transcript->translation;
        next unless (defined $translation);

        if(defined($self->param('pseudo_stableID_prefix'))) {
            $transcript->stable_id($self->param('pseudo_stableID_prefix') ."T_". $transcript->dbID);
            $translation->stable_id($self->param('pseudo_stableID_prefix') ."P_". $translation->dbID);
        }

        $self->param('transcriptCount', $self->param('transcriptCount')+1 );
        print("     transcript " . $transcript->stable_id ) if($self->param('verbose'));

        unless (defined $translation->stable_id) {
            die "CoreDB error: does not contain translation stable id for translation_id ". $translation->dbID;
        }

        my $pep_member = Bio::EnsEMBL::Compara::SeqMember->new_from_Transcript(
            -TRANSCRIPT => $transcript,
            -GENOME_DB  => $self->param('genome_db'),
            -DNAFRAG    => $dnafrag,
            -TRANSLATE  => 1);

        print(" => pep_member " . $pep_member->stable_id) if($self->param('verbose'));

        unless($pep_member->sequence) {
            print "  => NO SEQUENCE for pep_member " . $pep_member->stable_id."\n";
            next;
        }
        print(" len=",$pep_member->seq_length ) if($self->param('verbose'));
        $longestTranslation = $pep_member if not defined $longestTranslation or $pep_member->seq_length > $longestTranslation->seq_length;

        # store gene_member here only if at least one peptide is to be loaded for
        # the gene.
        if ($self->param('store_genes')) {
            unless ($gene_member) {
                $gene_member = Bio::EnsEMBL::Compara::GeneMember->new_from_Gene(
                    -GENE       => $gene,
                    -DNAFRAG    => $dnafrag,
                    -GENOME_DB  => $self->param('genome_db'),
                );
                print(" => gene_member " . $gene_member->stable_id) if($self->param('verbose'));
                $gene_member_adaptor->store($gene_member);
                print(" : stored\n") if($self->param('verbose'));
            }

            print("     gene       " . $gene->stable_id ) if($self->param('verbose'));
            $pep_member->gene_member_id($gene_member->dbID);
        }

        if ($pep_member->sequence =~ /[OU]/ and not $self->param('allow_ambiguity_codes')) {
            my $seq = $pep_member->sequence;
            $seq =~ s/U/C/g;
            $seq =~ s/O/K/g;
            $pep_member->sequence($seq);
        }
        $seq_member_adaptor->store($pep_member);
        if ($self->param('store_related_pep_sequences')) {
            $pep_member->_prepare_cds_sequence;
            $sequence_adaptor->store_other_sequence($pep_member, $pep_member->other_sequence('cds'), 'cds');
            $pep_member->_prepare_exon_sequences;
            $sequence_adaptor->store_other_sequence($pep_member, $pep_member->other_sequence('exon_bounded'), 'exon_bounded');
        }

        print(" : stored\n") if($self->param('verbose'));

        if(($transcript->stable_id eq $canonical_transcript_stable_id) || defined($self->param('force_unique_canonical'))) {
            $canonicalPeptideMember = $pep_member;
        }

    }

    # Some of the "polymorphic_pseudogene" have a non-translatable canonical peptide. This is a hack to get the longest translation
    if ($longestTranslation and not defined $canonicalPeptideMember and $self->param('find_canonical_translations_for_polymorphic_pseudogene') and $gene->biotype eq 'polymorphic_pseudogene') {
        $self->warning($gene->stable_id."'s canonical transcript does not have a translation. Will use the longest peptide instead: ".$longestTranslation->stable_id);
        $canonicalPeptideMember = $longestTranslation;
    }

    if($canonicalPeptideMember) {
        $seq_member_adaptor->_set_member_as_canonical($canonicalPeptideMember);
        # print("     LONGEST " . $canonicalPeptideMember->stable_id . "\n");
    } else {
        $self->warning(sprintf('No canonical peptide for %s', $gene->stable_id));
    }

    return 1;
}


sub store_all_coding_exons {
  my ($self, $genes, $dnafrag) = @_;

  return 1 if (scalar @$genes == 0);

  my $min_exon_length = $self->param_required('min_length');

  my $seq_member_adaptor = $self->compara_dba->get_SeqMemberAdaptor();
  my $genome_db = $self->param('genome_db');
  my @exon_members = ();

  foreach my $gene (@$genes) {
      #print " gene " . $gene->stable_id . "\n";

    foreach my $transcript (@{$gene->get_all_Transcripts}) {
      $self->param('transcriptCount', $self->param('transcriptCount')+1);

      print("     transcript " . $transcript->stable_id ) if($self->param('verbose'));
      
      foreach my $exon (@{$transcript->get_all_translateable_Exons}) {
#	  print "        exon " . $exon->stable_id . "\n";
        unless (defined $exon->stable_id) {
          warn("COREDB error: does not contain exon stable id for translation_id ".$exon->dbID."\n");
          next;
        }
        my $description = $self->fasta_description($exon, $transcript);
        
        my $exon_member = new Bio::EnsEMBL::Compara::SeqMember(
            -source_name    => 'ENSEMBLPEP',
            -genome_db_id   => $genome_db->dbID,
            -stable_id      => $exon->stable_id
        );
        $exon_member->taxon_id($genome_db->taxon_id);
        if(defined $description ) {
          $exon_member->description($description);
        } else {
          $exon_member->description("NULL");
        }
        $exon_member->dnafrag($dnafrag);
        $exon_member->dnafrag_start($exon->seq_region_start);
        $exon_member->dnafrag_end($exon->seq_region_end);
        $exon_member->dnafrag_strand($exon->seq_region_strand);
        $exon_member->version($exon->version);

	#Not sure what this should be but need to set it to something or else the members do not get added
	#to the exon_member table in the store method of MemberAdaptor
	$exon_member->display_label("NULL");
        
        my $seq_string = $exon->peptide($transcript)->seq;
        ## a star or a U (selenocysteine) in the seq breaks the pipe to the cast filter for Blast
        $seq_string =~ tr/\*U/XX/;
        if ($seq_string =~ /^X+$/) {
          warn("X+ in sequence from exon " . $exon->stable_id."\n");
        }
        else {
          $exon_member->sequence($seq_string);
        }

        print(" => exon_member " . $exon_member->stable_id) if($self->param('verbose'));

        unless($exon_member->sequence) {
          print("  => NO SEQUENCE!\n") if($self->param('verbose'));
          next;
        }
        print(" len=",$exon_member->seq_length ) if($self->param('verbose'));
        next if ($exon_member->seq_length < $min_exon_length);
        push @exon_members, $exon_member;
      }
    }
  }
  @exon_members = sort {$b->seq_length <=> $a->seq_length} @exon_members;
  my @exon_members_stored = ();
  while (my $exon_member = shift @exon_members) {
    my $not_to_store = 0;
    foreach my $stored_exons (@exon_members_stored) {
      if ($exon_member->dnafrag_start <=$stored_exons->dnafrag_end &&
          $exon_member->dnafrag_end >= $stored_exons->dnafrag_start) {
        $not_to_store = 1;
        last;
      }
    }
    next if ($not_to_store);
    push @exon_members_stored, $exon_member;

    eval {
	    #print "New seq_member\n";
	    $seq_member_adaptor->store($exon_member);
	    print(" : stored\n") if($self->param('verbose'));
    };
  }
}


sub fasta_description {
  my ($self, $gene, $transcript) = @_;

  my $description = "Transcript:" . $transcript->stable_id .
                    " Gene:" .      $gene->stable_id .
                    " Chr:" .       $gene->seq_region_name .
                    " Start:" .     $gene->seq_region_start .
                    " End:" .       $gene->seq_region_end;
  return $description;
}


1;
