# $Id$

package EnsEMBL::Web::ZMenu::RegFeature;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object       = $self->object; 
  my $species_path = $object->species_path;
  my $fid          = $object->param('fid')   || die 'No feature ID value in params';
  my $ftype        = $object->param('ftype') || die 'No feature type value in params';
  my $dbid         = $object->param('dbid');
  my $feature      = $object->database('funcgen')->get_ExternalFeatureAdaptor->fetch_by_dbID($dbid);
  my $location     = $feature->slice->seq_region_name . ':' . $feature->start . '-' . $feature->end;
  my $caption      = 'Regulatory Region';
  my $factor       = $fid;
  my ($feature_link, $factor_link);
  
  if ($ftype eq 'cisRED') {
    $factor =~ s/\D*//g;
    
    $feature_link = $self->object->species_defs->ENSEMBL_EXTERNAL_URLS->{'CISRED'}; 
    $feature_link =~ s/###ID###/$factor/;
    
    $factor_link = "$species_path/Location/Genome?ftype=RegulatoryFactor;dbid=$dbid;id=$fid";
  } elsif ($ftype eq 'miRanda') {
   (my $name = $fid) =~ /\D+(\d+)/;
    my @temp = split /:/, $name;
    
    $factor  = $temp[1];
    $factor_link = "$species_path/Location/Genome?ftype=RegulatoryFactor;id=$factor;name=$fid";
  } elsif ($ftype eq 'vista_enhancer') {
    $factor_link = "$species_path/Location/Genome?ftype=RegulatoryFactor;id=$factor;name=$fid";
  } elsif ($ftype eq 'NestedMICA') {
    $factor_link = "$species_path/Location/Genome?ftype=RegulatoryFactor;id=$factor;name=$fid";
    $feature_link = "http://servlet.sanger.ac.uk/tiffin/motif.jsp?acc=$fid";
  } elsif ($ftype eq 'cisred_search') {
    my ($id, $analysis_link, $associated_link, $gene_reg_link);
    
    foreach my $dbe (@{$feature->get_all_DBEntries}) {
      my $dbname = $dbe->dbname;
      $id = $dbe->primary_id;
      
      if ($dbname =~ /gene/i) {
        $associated_link = $object->_url({ type => 'Gene', action => 'Summary',    g => $id });
        $gene_reg_link   = $object->_url({ type => 'Gene', action => 'Regulation', g => $id });
        
        $analysis_link = $self->object->species_defs->ENSEMBL_EXTERNAL_URLS->{'CISRED'};
        $analysis_link =~ s/siteseq\?fid=###ID###/gene_view?ensembl_id=$id/;
      } elsif ($dbname =~ /transcript/i) {
        $associated_link = $object->_url({ type => 'Transcript', action => 'Summary', t => $id });
      } elsif ($dbname =~ /transcript/i) {
        $associated_link = $object->_url({ type => 'Transcript', action => 'Summary', p => $id });
      }
    }
    
    $caption = 'Regulatory Search Region';
    
    $self->add_entry({
      type       => 'Analysis',
      label_html => $ftype,
      link       => $analysis_link
    });
    
    $self->add_entry({
      type       => 'Target Gene',
      label_html => $id,
      link       => $associated_link
    });
    
    if ($object->parent->{'ENSEMBL_TYPE'} ne 'Regulation') {
      $self->add_entry({
        label_html => 'View Gene Regulation',
        link       => $gene_reg_link
      });
    }
  }

  # add zmenu items that apply to all external regulatory features
  if ($ftype ne 'cisred_search') { 
    $self->add_entry({
      type       => 'Feature',
      label_html => $fid,
      link       => $feature_link
    });
    
    $self->add_entry({
      type       => 'Factor',
      label_html => $factor,
      link       => $factor_link
    });
  }
  
  $self->add_entry({
    type       => 'bp',
    label_html => $location,
    link       => $object->_url({
      type   => 'Location',
      action => 'View',
      r      => $location
    })
  });
  
  $self->caption($caption);
}

1;
