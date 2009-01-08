package EnsEMBL::Web::Component::Variation::Summary;

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

  ## Add feature type and source
  my $name = $object->name;
  my $source = $object->source;
  $name      = $object->get_ExtURL_link($source, 'SNP', $name) if $source eq 'dbSNP';
  $name = "SNP (source $name)"; 
  my $html  = '';
  $html .= qq(<dl class="summary">
     <dt> Variation type </dt> 
     <dd>$name</dd>
  );
 
  ## Add synonyms
  my %synonyms = %{$object->dblinks};
  my $info;
    foreach my $db (keys %synonyms) {
    my @ids =  @{ $synonyms{$db} } ;
    my @urls;

    
    if ($db =~ /dbsnp rs/i) {  # Glovar stuff
      @urls  = map {  $object->get_ExtURL_link( $_, 'SNP', $_)  } @ids;
    }
    elsif ($db =~ /dbsnp/i) {
      foreach (@ids) {
  next if $_ =~/^ss/; # don't display SSIDs - these are useless
  push @urls , $object->get_ExtURL_link( $_, 'DBSNPSS', $_ );
      }
      next unless @urls;
    } elsif( $db =~/HGVbase|TSC/){
      next;
    }  else {
      @urls = @ids;
    }

    # Do wrapping
    for (my $counter = 7; $counter < $#urls; $counter +=7) {
      my @front = splice (@urls, 0, $counter);
      $front[-1] .= "</tr><tr><td></td>";
      @urls = (@front, @urls);
    }

    $info .= "<b>$db</b> ". (join ", ", @urls ). "<br />";
  }

  $info ||= "None currently in the database";
 
  $html .= qq(<dt>Synonyms</dt>
     <dd>$info</dd>); 

  ## Add Alleles
   my $label = 'Alleles';
   my $alleles = $object->alleles;
   my $vari_class = $object->vari_class || "Unknown";
   my $allele_html;

   if ($vari_class ne 'snp') {
     $allele_html = qq(<b>$alleles</b> (Type: <strong>$vari_class</strong>));
   }
   else {
     my $ambig_code = $object->vari->ambig_code;
     $allele_html = qq(<b>$alleles</b> (Ambiguity code: <strong>$ambig_code</strong>));
   }
   my $ancestor  = $object->ancestor;
   $allele_html .= qq(<br /><em>Ancestral allele</em>: $ancestor) if $ancestor;

    $html .= qq(<dt>Alleles</dt>
     <dd>$allele_html</dd>);
    $html .="</dl>";
    

  ## Add location information
  my $location; 
  my $strand = "(forward strand)";
  my %mappings = %{ $object->variation_feature_mapping };
  my $count = scalar (keys %mappings);
  $html  .= qq( <dl class="summary">);
  my $id = $object->name;
  my $action = $object->action;

  if ($count < 1) {
   $html .= qq(<dt>Location</dt><dd>This feature has not been mapped.</dd>i</dl>);
  } elsif ($count ==1){
   $location = $object->var_location;
   foreach my $varif_id (keys %mappings) {
     my %chr_info;
     my $region = $mappings{$varif_id}{Chr}; 
     my $start  = $mappings{$varif_id}{start};
     my $end    = $mappings{$varif_id}{end};
     my $display_region = $region .':' . ($start -10) .'-'. ($end +10);
     my $link = $object->_url({ 'type'=>'Location', 'action'=>'View', 'v' => $id,'source' => $source, 'vf' => $varif_id});
     my $str = $mappings{$varif_id}{strand};
     if ($str < 0 ) {$strand ="(reverse strand)";} 
     my $location_string;
     if ($start == $end ) { $location_string =  $region.":".$start;}
     else { $location_string = $region.":".$start."-".$end; } 
     my $location_html = qq(<a href="$link">$location_string</a> $strand) ;
     $html .= qq(<dt>Location</dt><dd>$location_html</dd></dl>);
   }
  }else {
    my @locations;
    $html .= qq(<dt>Location</dt><dd><p id="locations_text"> This feature maps to $count genomic locations: </p>
    <table id="locations" style="display:none">);
 
     
    foreach my $varif_id (keys %mappings) {
     my %chr_info;
     my $region = $mappings{$varif_id}{Chr}; 
     my $start  = $mappings{$varif_id}{start};
     my $end    = $mappings{$varif_id}{end};
     my $display_region = $region .':' . ($start -10) .'-'. ($end +10); 
     my $link = $object->_url({'type'=>'Location', 'action'=>'View', 'v' => $id, 'source' => $source, 'vf' => $varif_id});  
     my $str = $mappings{$varif_id}{strand};
     if ($str <= 0 ) {$strand ="(reverse strand)";}
     else {$strand = "(forward strand)"; }
     my $location_string; 
     if ($start == $end ) { $location_string =  $region.":".$start;}
     else { $location_string = $region.":".$start."-".$end; }
     my $location_html = qq(<a href="$link">$location_string</a> $strand) ;

      $html.= qq(<tr><td>$location_html</td></tr>);
    }
   $html .= "</table></dd>";
  }


  return $html;
}

1;
