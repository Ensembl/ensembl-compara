# $Id$

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
  my $matches    = $self->_matches('similarity_matches', 'Similarity Matches', 'PRIMARY_DB_SYNONYM', 'MISC', 'LIT','RenderAsTables');
  my $no_matches = qq(No external references assigned to this gene. Please see the transcript pages for references attached to this gene's transcript(s) and protein(s));  
  my $html       = $matches ? $matches : $no_matches;   
  $html         .= $self->matches_to_html('MISC', 'LIT');
  return $html;
}

sub matches_to_html {
  my $self           = shift;
  my @types          = @_;
  my $hub            = $self->hub;
  my $count_ext_refs = 0;
  my $table          = $self->new_table([], [], { data_table => 'no_col_toggle', sorting => [ 'transcriptid asc' ] });
  my (%existing_display_names, @rows, $html);
  
  my @columns = ({
    key        => 'transcriptid' ,
    title      => 'Transcript ID',
    align      => 'left',
    sort       => 'string',
    priority   => 2147483647, # Give transcriptid the highest priority as we want it to be the 1st colum
    display_id => '',
    link_text  => ''
  }); 
  
  foreach (@{$self->object->Obj->get_all_Transcripts}) {
	  my $url = sprintf '<a href="%s">%s</a>', $hub->url({ type => 'Transcript', action => 'Summary', function => undef, t => $_->stable_id }), $_->stable_id;
    my $row = { transcriptid => $url };
    
    foreach ($self->get_matches_by_transcript($_, @types)) {
	    next unless defined $hub->param($_->db_display_name) && $hub->param($_->db_display_name) ne 'off';
      
      my %similarity_links = $self->get_similarity_links_hash($_);
      my $ext_db_entry     = $similarity_links{'link'} ? qq{<a href="$similarity_links{'link'}">$similarity_links{'link_text'}</a>}  : $similarity_links{'link_text'};

      $row->{$_->db_display_name} .= ' ' if defined $row->{$_->db_display_name};
      $row->{$_->db_display_name} .= $ext_db_entry;
      
      $count_ext_refs++;
      
      if (!defined $existing_display_names{$_->db_display_name}) {
        push @columns, {
          key        => $_->db_display_name, 
          title      => $self->format_column_header($_->db_display_name, $similarity_links{'link_text'}), 
          align      => 'left', 
          sort       => 'string', 
          priority   => $_->priority, 
          display_id => $_->display_id, 
          link_text  => $similarity_links{'link_text'}
        };
        
        $existing_display_names{$_->db_display_name} = 1;
      }
    }
    
    push @rows, $row;
  }
  
  @columns = sort { $b->{'priority'} <=> $a->{'priority'} || $a->{'title'} cmp $b->{'title'} || $a->{'link_text'} cmp $b->{'link_text'} } @columns;
  @rows    = sort { keys %{$b} <=> keys %{$a} } @rows; # show rows with the most information first
  
  $table->add_columns(@columns);   
  $table->add_rows(@rows);
  
  if ($count_ext_refs == 0) {
    $html.= '<p><strong>No (selected) external database identifiers correspond to Transcripts of this Gene: <br/>(note: empty columns are hidden)</strong></p>';
  } else {
    $html .= '<p><strong>The following database identifier' . ($count_ext_refs > 1 ? 's' : '') . ' correspond' . ($count_ext_refs > 1 ? '' : 's') . ' to Transcripts of this Gene:</strong></p>';
    $html .= $table->render;
  }
  
  return $html;
}

sub format_column_header {
  my $self            = shift;
  my $column_header   = shift;
  my $value           = shift;
  $column_header      =~ s/\//\/ /; # add a space after a /, which enables the table haeader to split the name into multiple lines if needed.
  my @header_segments = split / /, $column_header;
  
  foreach (@header_segments) {
    if (length $value < length $_) {
      $_= substr($_, 0, length($value) - 1) . '- <br/>' . $self->format_column_header(substr($_, length($value) - 1, length $_), $value);
    }
  }
  
  $column_header  = '';
  $column_header .= "$_ " for @header_segments;
  
  return $column_header;
}

sub get_matches_by_transcript {
  my $self          = shift;
  my $transcript    = shift;
  my @types         = @_;  
  my %allowed_types = map { $_ => 1 } @types;
  my $db_links;
  my @return_links;
  
  eval { 
    $db_links = $transcript->get_all_DBLinks;
  };
  
  foreach (@$db_links) {
    if (defined $allowed_types{$_->type}) { 
      $_->{'transcript'} = $transcript;
      push @return_links, $_;
    }
  }
  
  return @return_links;
}

sub get_similarity_links_hash {
   my $self       = shift;
   my $type       = shift;
   my $hub        = $self->hub;
   my $urls       = $hub->ExtURL;
   my $fv_type    = $hub->action eq 'Oligos' ? 'OligoFeature' : 'Xref'; # default link to featureview is to retrieve an Xref
   my $externalDB = $type->database;
   my $display_id = $type->display_id;
   
   next if $type->status eq 'ORTH';                            # remove all orthologs
   next if lc $externalDB eq 'medline';                        # ditch medline entries - redundant as we also have pubmed
   next if $externalDB =~ /^flybase/i && $display_id =~ /^CG/; # ditch celera genes from FlyBase
   next if $externalDB eq 'Vega_gene';                         # remove internal links to self and transcripts
   next if $externalDB eq 'Vega_transcript';
   next if $externalDB eq 'Vega_translation';
   next if $externalDB eq 'OTTP' && $display_id =~ /^\d+$/;    # don't show vega translation internal IDs   
   
   my $text       = $display_id;
   my $primary_id = $type->primary_id;
   my %similarity_links;
   
   # hack for LRG in e58
   $primary_id =~ s/_g\d*$// if $externalDB eq 'ENS_LRG_gene';

   (my $A = $externalDB) =~ s/_predicted//;
   
   $similarity_links{'link'}      = $urls->get_url($A, $primary_id) if $urls && $urls->is_linked($A);
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
