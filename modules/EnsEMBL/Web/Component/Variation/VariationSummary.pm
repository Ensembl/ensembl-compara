package EnsEMBL::Web::Component::Variation::VariationSummary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Variation);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = '';
  
  ## Add validation status
  my $stat;
  my @status = @{$object->status};
  if ( @status ) {
  my $snp_name = $object->name;
  my (@status_list, $hapmap_html);
  foreach my $status (@status) {
    if ($status eq 'hapmap') {
      $hapmap_html = "<b>HapMap SNP</b>", $object->get_ExtURL_link($snp_name, 'HAPMAP', $snp_name);
    }
    elsif ($status eq 'failed') {
      my $description = $object->vari->failed_description;
      return $status;
    }
    else {
      $status = "frequency" if $status eq 'freq';
      push @status_list, $status;
    }
  }
  $stat = join(", ", @status_list);
  if ($stat) {
    if ($stat eq 'observed' or $stat eq 'non-polymorphic') {
      $html = '<b>'.ucfirst($stat).'</b> ';
    } else {
      $stat = "Proven by <b>$stat</b> ";
    }
    $stat .= ' (<i>Feature tested and validated by a non-computational method</i>).<br /> ';
  }
   $stat .= $hapmap_html;
  } else { 
   $stat = "Unknown";
  }

   unless ($stat=~/^\w/) { $stat = "Undefined"; }
   $html .= qq(
       <dl class="summary">
      <dt>Validation status</dt>
      <dd> $stat</dd>);

  ## Add LD data  
  my $ld_html;
  my $label = "Linkage disequilibrium data";

   ## First check that a location has been selected:
  if  ($object->core_objects->location ){
    warn "TEST" .$object->species_defs->VARIATION_LD; 
    if  ($object->species_defs->VARIATION_LD) {         
    }else {
      $ld_html = "<h5>No linkage data available for this species</h5>";
    }

  } ## If no location selected direct the user to pick one from the summary panel 
   else {
     $ld_html = "You must select a location from the panel above to see Linkage disequilibrium data";
  }

   $html .= qq(<dt>$label</dt>
      <dd> $ld_html</dd></dl>);
  
       
  return $html;
}

1;
