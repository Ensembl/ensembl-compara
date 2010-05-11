package EnsEMBL::Web::Component::Variation::FlankingSequence;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = '';
  ## first check we have a location
  return if $object->not_unique_location;


  ## Add flanking sequence
  my $f_label;
  my $f_html ;

  my $status   = 'status_ambig_sequence';
  my $URL = _flip_URL( $object, $status );
  #if( $object->param( $status ) eq 'off' ) { $panel->add_row( $label, '', "$URL=on" ); return 0; }

  my $ambig_code = $object->vari->ambig_code;
  unless ($ambig_code) {
    $ambig_code = "[".$object->alleles."]";
  }
  
  # first determine correct SNP location 
  my %mappings = %{ $object->variation_feature_mapping }; 
  my $loc;
  if( keys %mappings == 1 ) {
    ($loc) = values %mappings;
  } else { 
    $loc = $mappings{$object->param('vf')};
  }
  
  # get a slice adaptor
  my $sa = $object->vari->adaptor->db->dnadb->get_SliceAdaptor(); 
  
  
  ## FLANKING SEQUENCE  
  my ($up_slice, $down_slice);
  
  my $flank_size = $object->param('flank_size') || 400;
  my $show_mismatches = $object->param('show_mismatches') || 1;
  
  if(defined($sa)) {
    # get up slice
    $up_slice = $sa->fetch_by_region(
      undef,
      $loc->{Chr},
      $loc->{start} - $flank_size,
      $loc->{start} - 1,
      $loc->{strand}
    );
    
    # get down slice
    $down_slice = $sa->fetch_by_region(
      undef,
      $loc->{Chr},
      $loc->{end} + 1,
      $loc->{end} + $flank_size,
      $loc->{strand}
    );
    
    # switch if on reverse strand
    ($up_slice, $down_slice) = ($down_slice, $up_slice) unless $loc->{strand} == 1;
    
    $f_label = "Flanking Sequence<br/>(reference".($object->vari->{flank_flag} ? "" : " and ".$object->vari->source).")";
    
    # make HTML if we got slices OK
    if(defined($up_slice) && defined($down_slice)) {
      $f_html = uc( $up_slice->seq ) .lc( $ambig_code ).uc( $down_slice->seq );
      $f_html =~ s/(.{60})/$1\n/g;
      $f_html =~ s/(([a-z]|\/|-|\[|\])+)/'<span class="alt_allele">'.uc("$1").'<\/span>'/eg;
      $f_html =~ s/\n/\n/g;
      
      $html .=  qq(<dl class="summary">
        <dt>$f_label</dt>
        <dd><pre>$f_html</pre>
        <blockquote><em>(Variant highlighted)</em></blockquote></dd></dl>);
    }
  }

  #  my $ambiguity_seq = $object->ambiguity_flank;
  # genomic context with ambiguities
  
  if($object->vari->{flank_flag} || !defined($up_slice) || !defined($down_slice) || !defined($sa)) {
    my ($up_source, $down_source) = ($object->flanking_seq("up"), $object->flanking_seq("down"));
    
    # code to highlight differences between reference and source flanking sequence
    if(defined($up_slice) && defined($down_slice) && $show_mismatches eq 'yes') {
      
      # get expanded (or retracted!) up and down reference sequences
      $up_slice = $up_slice->expand(length($up_source) - $up_slice->length());
      $down_slice = $down_slice->expand(undef, length($down_source) - $down_slice->length());
      my ($up_ref, $down_ref) = ($up_slice->seq, $down_slice->seq);
      
      # compare up seq
      for my $i(0..(length($up_ref)-1)) {
        if(substr($up_ref, $i, 1) ne substr($up_source, $i, 1)) {
          my $letter = uc(substr($up_source, $i, 1));
          $letter =~ tr/ACGTN/\!\£\$\%\@/;
          substr($up_source, $i, 1) = $letter;
        }
      }
      
      # compare down seq
      for my $i(0..(length($down_ref)-1)) {
        if(substr($down_ref, $i, 1) ne substr($down_source, $i, 1)) {
          my $letter = uc(substr($down_source, $i, 1));
          $letter =~ tr/ACGTN/\!\£\$\%\@/;
          substr($down_source, $i, 1) = $letter;
        }
      }
    }
    
    $f_html = uc( $up_source ) .lc( $ambig_code ).uc( $down_source );
    $f_html =~ s/(.{60})/$1\n/g;
    $f_html =~ s/(([a-z]|\/|-|\[|\])+)/'<span class="alt_allele">'.uc("$1").'<\/span>'/eg;
    $f_html =~ s/[\!\£\$\%\@]+/'<span style="color:blue;">'.uc("$&").'<\/span>'/eg;
    $f_html =~ tr/\!\£\$\%\@/ACGTN/;
    $f_html =~ s/\n/\n/g;
    
    #warn $f_html;
  
    $f_label = 'Flanking Sequence<br />('.$object->vari->source.')';
    
    my $key;
    
    if($show_mismatches eq 'yes') {
      $key = ' in red, differences highlighted in blue'
    }
    
    $html .=  qq(<dl class="summary">
        <dt>$f_label</dt>
        <dd><pre>$f_html</pre>
        <blockquote><em>(Variant highlighted$key)</em></blockquote></dd></dl>);
  }


  return $html;
}

sub _flip_URL {
  my( $object, $code ) = @_;
  return sprintf '/%s/%s?snp=%s;db=%s;%s', $object->species, $object->script, $object->name, $object->param('source'), $code;
}

1;
