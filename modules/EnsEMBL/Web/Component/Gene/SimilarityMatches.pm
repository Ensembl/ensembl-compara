=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene::SimilarityMatches;

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self       = shift;
  my @dbtypes   = qw(MISC LIT);
  my $matches    = $self->_matches('similarity_matches', 'Similarity Matches', 'PRIMARY_DB_SYNONYM', @dbtypes, 'RenderAsTables');
  my $no_matches = qq(<p>No external references assigned to this gene.</p><br />);
  my $html       = $matches ? $matches : $no_matches;
  $html         .= $self->matches_to_html(@dbtypes) if($self->hub->species_defs->ENSEMBL_SUBTYPE ne 'mobile');
  return $html;
}

sub matches_to_html {
  my $self           = shift;
  my @dbtypes          = @_;
  my $hub            = $self->hub;
  my $count_ext_refs = 0;
  my (@rows, $html);

  my @columns = ({ 
                  key        => 'transcriptid',
                  title      => 'Transcript ID',
                  align      => 'left',
                  sort       => 'string',
                });

  my (%seen, %hidden_columns, %columns_with_data);

  my @other_columns = @{$hub->species_defs->DEFAULT_XREFS||[]};
  foreach (@other_columns) {
    $_ =~ s/_/ /g;
    push @columns, {
                   key    => $_,
                   title  => $self->format_column_header($_),
                   align  => 'left',
                   sort   => 'string',
                  };
    $seen{$_} = 1;
    $hidden_columns{$_} = 0;
  }

  my @all_xref_types = keys %{$hub->species_defs->XREF_TYPES||{}};
  foreach (sort @all_xref_types) {
    next if $seen{$_};  
    push @columns, {
                    key    => $_,
                    title  => $self->format_column_header($_),
                    align  => 'left',
                    sort   => 'string',
                   };
    $hidden_columns{$_} = 1;
  }
  

  foreach my $transcript (@{$self->object->Obj->get_all_Transcripts}) {
    my $url = sprintf '<a href="%s">%s</a>', $hub->url({ type => 'Transcript', action => 'Summary', function => undef, t => $transcript->stable_id }), $transcript->version ? $transcript->stable_id.".".$transcript->version : $transcript->stable_id;
    my $row = { 'transcriptid' => $url };
    $columns_with_data{'transcriptid'} = 1;

    foreach my $db_entry ($self->get_matches_by_transcript($transcript, @dbtypes)) {
      my $key = $db_entry->db_display_name;
      my %matches = $self->get_similarity_links_hash($db_entry);

      $row->{$key} .= ' ' if defined $row->{$key};
      $row->{$key} .=  $matches{'link'} ? sprintf('<a href="%s">%s</a>', $matches{'link'}, $matches{'link_text'})  : $matches{'link_text'};
      $count_ext_refs++;
      $columns_with_data{$key}++;
    }
    if (keys %$row) {
      push @rows, $row;
    }
  }
  @rows = sort { keys %{$b} <=> keys %{$a} } @rows; # show rows with the most information first

  ## Hide columns with no values, as well as those not shown by default
  my @hidden_cols;
  my $i = 0;
  foreach (@columns) {
    if ($hidden_columns{$_->{'key'}} || !$columns_with_data{$_->{'key'}}) {
      push @hidden_cols, $i;
    }
    $i++; 
  }  

  my $table = $self->new_table(\@columns, \@rows, { 
                                                data_table => 1, 
                                                exportable => 1, 
                                                hidden_columns => \@hidden_cols, 
                                                class=>"mobile-nolink",
                                              });

  if ($count_ext_refs == 0) {
    $html.= '<p><strong>No (selected) external database contains identifiers which correspond to the transcripts of this gene.</strong></p>';
  } else {
    $html .= '<p><strong>The following database identifier' . ($count_ext_refs > 1 ? 's' : '') . ' correspond' . ($count_ext_refs > 1 ? '' : 's') . ' to the transcripts of this gene:</strong></p>';
    $html .= $table->render;
  }

  return $html;
}

sub format_column_header {
  my $self            = shift;
  my $column_header   = shift;
  $column_header      =~ s/\//\/ /; # add a space after a /, which enables the table header to split the name into multiple lines if needed.
  return $column_header;
}

sub get_matches_by_transcript {
  my $self          = shift;
  my $transcript    = shift;
  my @dbtypes       = @_;
  my @db_links;

  foreach (@dbtypes) {
    push @db_links, @{ $transcript->get_all_DBLinks(undef, $_) };
  }

  $_->{'transcript'} = $transcript for @db_links;
  
  return @db_links;
}

sub get_similarity_links_hash {
   my $self       = shift;
   my $type       = shift;
   my $hub        = $self->hub;
   my $urls       = $hub->ExtURL;
   my $fv_type    = $hub->action eq 'Oligos' ? 'OligoFeature' : 'Xref'; # default link to featureview is to retrieve an Xref
   my $externalDB = $type->database;
   my $display_id = $type->display_id;

   #one day should sort out the database so that we don't have to do these
   next if $type->status eq 'ORTH';                            # remove all orthologs
   next if lc $externalDB eq 'medline';                        # ditch medline entries - redundant as we also have pubmed
   next if $externalDB =~ /^flybase/i && $display_id =~ /^CG/; # ditch celera genes from FlyBase
   next if $externalDB eq 'Vega_gene';                         # remove internal links to self and transcripts
   next if $externalDB eq 'Vega_transcript' && $display_id !~ /OTT/; #only show OTT xrefs
   next if $externalDB eq 'Vega_translation' && $display_id !~ /OTT/; #only show OTT xrefs;
   next if $externalDB eq 'OTTP' && $display_id =~ /^\d+$/;    # don't show vega translation internal IDs   

   my $text       = $display_id;
   my $primary_id = $type->primary_id;
   my %similarity_links;

   # hack for LRG in e58
   $primary_id =~ s/_g\d*$// if $externalDB eq 'ENS_LRG_gene';

   (my $A = $externalDB) =~ s/_predicted//;

   $type->{ID} = $primary_id;
   $type->{GP} = $hub->species_defs->UCSC_GOLDEN_PATH if $A eq 'UCSC';
   $similarity_links{'link'} = $urls->get_url($A, $type) if $urls && $urls->is_linked($A);

   $similarity_links{'link_text'} = $A eq 'MARKERSYMBOL' ? " ($primary_id)" : $display_id;

   if ($hub->species_defs->ENSEMBL_PFETCH_SERVER && $externalDB =~ /^(SWISS|SPTREMBL|LocusLink|protein_id|RefSeq|EMBL|Gene-name|Uniprot)/i) {
     my $seq_arg = $display_id;
     $seq_arg    = "LL_$seq_arg" if $externalDB eq 'LocusLink';
     my $url = $hub->url({
       type     => 'Transcript',
       action   => 'Similarity/Align',
       sequence => $seq_arg,
       extdb    => lc $externalDB,
     });
     $similarity_links{'align_url'} = $url;
   }
   $similarity_links{'search_go_link'} = $urls->get_url('GOSEARCH', $primary_id) if $externalDB =~ /^(SWISS|SPTREMBL)/i; # add Search GO link;

    # add link to featureview
    ## FIXME - another LRG hack! 
    my $all_locations_url;
    if ($externalDB eq 'ENS_LRG_gene') {
      $all_locations_url = $hub->url({
        type    => 'LRG',
        action  => 'Genome',
        lrg     => $display_id,
      });
    } else {
      my $link_name = $fv_type eq 'OligoFeature' ? $display_id : $primary_id;
      my $link_type = $fv_type eq 'OligoFeature' ? $fv_type : "${fv_type}_$externalDB";
      $all_locations_url = $hub->url({
        type   => 'Location',
        action => 'Genome',
        id     => $link_name,
        ftype  => $link_type
      });
    }
    $similarity_links{'all_locations_url'} = $all_locations_url;
    return %similarity_links;
}


1;
