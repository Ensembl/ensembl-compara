package EnsEMBL::Web::Component::Info::SpeciesBlurb;

use strict;

use EnsEMBL::Web::Controller::SSI;

use base qw(EnsEMBL::Web::Component);


sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $species     = $hub->species;
  my $common_name = $hub->species_defs->SPECIES_COMMON_NAME;

  my $file1       = '/ssi/species/'.$species.'_assembly.html';
  my $file2       = '/ssi/species/'.$species.'_annotation.html';

  my $ensembl_version   = $hub->species_defs->ENSEMBL_VERSION;
  my $current_assembly  = $hub->species_defs->ASSEMBLY_NAME;

  ## Assembly blurb
  my $html = EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $file1);

  ## Add in GCA link 
  if ($hub->species_defs->ASSEMBLY_ACCESSION){
    my $accession_link = $hub->get_ExtURL_link($hub->species_defs->ASSEMBLY_ACCESSION, 'GCA', $hub->species_defs->ASSEMBLY_ACCESSION);
    $html .= qq(<p class="space-below">The genome assembly represented here corresponds to GenBank Assembly ID $accession_link</p>);
  }

  ## Link to FTP site
 if ($hub->species_defs->ENSEMBL_SITETYPE ne 'Pre'){
  my $ftp_url = 'ftp://ftp.ensembl.org/pub/release-'.$ensembl_version.'/fasta/'.lc($species).'/dna/';
  $html .= qq(<p style="margin-top:1em"><a href=$ftp_url"><img src="/i/helix.gif" alt="" /></a>
                <a href="$ftp_url">Download $common_name genome sequence</a> (FASTA)</p>);
  }

  ## Insert dropdown list of old assemblies
  my %archive = %{$hub->species_defs->get_config($species, 'ENSEMBL_ARCHIVES')||{}};
  my %assemblies = %{$hub->species_defs->get_config($species, 'ASSEMBLIES')||{}};

  my @old_archives;
  my $previous = $current_assembly;
  foreach my $release (reverse sort keys %archive) {
    next if $release == $hub->species_defs->ENSEMBL_VERSION;
    next if $assemblies{$release} eq $previous;
    push @old_archives, {
        'url' => 'http://'.lc($archive{$release}).".archive.ensembl.org/$species/", 
        'text' => $assemblies{$release}.' (Release '.$release.', '.$archive{$release}.')',
    };
    $previous = $assemblies{$release};
  }

  if (@old_archives) {
    $html .= '<h3 style="clear:both;padding-top:1em">Previous assemblies</h3>';
    $html .= qq{
      <form action="/$species/redirect" method="get">
        <select name="url">
    };
    foreach my $archive (@old_archives) {
      $html .= '<option value="'.$archive->{'url'}.'">'.$archive->{'text'}.'</option>';
    }
    $html .= qq{
        </select> <input type="submit" name="submit" value="Go to archive" />
      </form>
    };
  }

  ## Annotation blurb
  $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $file2);
  
  return $html;  
}

1;
