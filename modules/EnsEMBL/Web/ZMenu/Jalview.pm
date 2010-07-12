# $Id$

# Constructs the html needed to launch jalview for fasta and nh file urls

package EnsEMBL::Web::ZMenu::Jalview;

use URI::Escape qw(uri_unescape);

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self     = shift;
  my $hub      = $self->hub;
  my $url_site = $hub->species_defs->ENSEMBL_BASE_URL;
  my $html     = sprintf(
    '<applet code="jalview.bin.JalviewLite" width="140" height="35" archive="%s/jalview/jalviewAppletOld.jar">
      <param name="file" value="%s">
      <param name="treeFile" value="%s">
      <param name="sortByTree" value="true">
      <param name="defaultColour" value="clustal">
    </applet>', 
    $url_site, 
    $url_site . uri_unescape($hub->param('file')),
    $url_site . uri_unescape($hub->param('treeFile'))
  );
  
  $self->add_entry({
    type       => 'View Sub-tree',
    label      => '[Requires Java]',
    label_html => $html
  });
}

1;
