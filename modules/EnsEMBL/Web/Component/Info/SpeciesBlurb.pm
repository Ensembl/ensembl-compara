# $Id$

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
  my $self              = shift;
  my $hub               = $self->hub;
  my $species_defs      = $hub->species_defs;
  my $species           = $hub->species;
  my $common_name       = $species_defs->SPECIES_COMMON_NAME;
  my $ensembl_version   = $species_defs->ENSEMBL_VERSION;
  my $current_assembly  = $species_defs->ASSEMBLY_NAME;
  my $accession         = $species_defs->ASSEMBLY_ACCESSION;
  my $source            = $species_defs->ASSEMBLY_ACCESSION_SOURCE || 'NCBI';
  my $source_type       = $species_defs->ASSEMBLY_ACCESSION_TYPE;
  my %archive           = %{$species_defs->get_config($species, 'ENSEMBL_ARCHIVES') || {}};
  my %assemblies        = %{$species_defs->get_config($species, 'ASSEMBLIES')       || {}};
  my $previous          = $current_assembly;
  my $html              = EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/${species}_assembly.html"); ## Assembly blurb
  my @old_archives;
  
  $html .= sprintf '<p>The genome assembly represented here corresponds to %s %s</p>', $source_type, $hub->get_ExtURL_link($accession, "ASSEMBLY_ACCESSION_SOURCE_$source", $accession) if $accession; ## Add in GCA link
  
  ## Link to FTP site
  if ($species_defs->ENSEMBL_SITETYPE ne 'Pre') {
    my $ftp_url = sprintf 'ftp://ftp.ensembl.org/pub/release-%s/fasta/%s/dna/', $ensembl_version, lc $species;
       $html   .= qq{<p><a href=$ftp_url"><img src="/i/helix.gif" alt="" /></a><a href="$ftp_url">Download $common_name genome sequence</a> (FASTA)</p>};
  }

  ## Insert dropdown list of old assemblies
  foreach my $release (reverse sort keys %archive) {
    next if $release == $ensembl_version;
    next if $assemblies{$release} eq $previous;
    
    push @old_archives, {
      url  => sprintf('http://%s.archive.ensembl.org/%s/', lc $archive{$release}, $species),
      text => "$assemblies{$release} (Release $release, $archive{$release})",
    };
    
    $previous = $assemblies{$release};
  }

  if (@old_archives) {
    $html .= sprintf('
      <h3 style="clear:both">Previous assemblies</h3>
      <form action="/%s/redirect" method="get">
        <select name="url">
          %s
        </select> <input type="submit" name="submit" value="Go to archive" />
      </form>
    ', $species, join '', map qq{<option value="$_->{'url'}">$_->{'text'}</option>}, @old_archives);
  }

  
  $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/${species}_annotation.html"); ## Annotation blurb
  
  return $html;  
}

1;
