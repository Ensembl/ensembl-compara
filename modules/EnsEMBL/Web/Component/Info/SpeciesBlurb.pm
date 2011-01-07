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

  my $common_name = $hub->species_defs->get_config($species, 'SPECIES_COMMON_NAME');
  my $file1       = '/ssi/species/'.$species.'_assembly.html';
  my $file2       = '/ssi/species/'.$species.'_annotation.html';

  $species        =~ s/_/ /g;
  my $name_string = $common_name =~ /\./ ? "<i>$species</i>" : "$common_name (<i>$species</i>)";
  my $html = "<h1>$name_string</h1>";

  ## Assembly blurb
  $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $file1);

  ## Insert dropdown list of old assemblies
  my $ensembl_version   = $hub->species_defs->ENSEMBL_VERSION;
  my $current_assembly  = $hub->species_defs->ASSEMBLY_NAME;
  my $species           = $hub->species;

  my %archive = %{$hub->species_defs->get_config($species, 'ENSEMBL_ARCHIVES')||{}};
  my %assemblies = %{$hub->species_defs->get_config($species, 'ASSEMBLIES')||{}};

  my @old_archives;
  my $previous = $current_assembly;
  foreach my $release (reverse sort keys %archive) {
    next if $release == $hub->species_defs->ENSEMBL_VERSION;
    next if $assemblies{$release} eq $previous;
    push @old_archives, {
        'url' => 'http://'.lc($archive{$release}).".archive.ensembl.org/$species/", 
        'text' => $assemblies{$release}.' ('.$archive{$release}.')',
    };
    $previous = $assemblies{$release};
  }

  if (@old_archives) {
    $html .= '<h3 style="clear:both">Previous assemblies</h3>';
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
