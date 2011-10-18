# $Id$

package EnsEMBL::Web::Component::UserData::SelectFeatures;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub caption {
  return 'Select File to Upload';
}

sub content {
  my $self            = shift;
  my $hub             = $self->hub;
  my $session         = $hub->session;
  my $species_defs    = $hub->species_defs;
  my $sitename        = $species_defs->ENSEMBL_SITETYPE;
  my $species         = $hub->species;
  my $current_species = $hub->data_species;
  my $html;

  ## Get necessary data first, to ensure we can do assembly mapping!
  my @species;
  foreach my $sp ($species_defs->valid_species) {
    if (scalar($species_defs->get_config($sp, 'ASSEMBLY_MAPPINGS')) > 0) {
      push @species, $sp;
    }
  }
  my %mappings;
  foreach my $sp (@species) {
    my $sp_map = $species_defs->get_config($sp, 'ASSEMBLY_MAPPINGS');
    if ($sp_map) {
      $mappings{$sp} = $sp_map;
    }
  }

  if (keys %mappings) {

    $html .= qq(
      <input type="hidden" class="panel_type" value="AssemblyMappings" />
    );

    my $form = $self->modal_form('select', $hub->species_path($current_species) . "/UserData/CheckConvert");
    $form->add_notes({'heading' => 'Tips',
  'text' => qq(<p class="space-below">Map your data to the current assembly. 
  The tool accepts a <a href="/info/website/upload/bed.html#required">list of simple coordinates</a>, 
  or files in these formats: 
  <a href="/info/website/upload/gff.html">GFF</a>,
  <a href="/info/website/upload/gff.html">GTF</a>,
  <a href="/info/website/upload/bed.html">BED</a>,
  <a href="/info/website/upload/psl.html">PSL</a>
</p>
<p class="space-below">N.B. Export is currently in GFF only</p>
<p>For large data sets, you may find it more efficient to use our <a href="ftp://ftp.ensembl.org/pub/misc-scripts/Assembly_mapper_1.0/">ready-made converter script</a>.</p>)
  });
    my $subheader = 'Upload file';

    ## Munge data needed for form elements
    my (@forward, @backward, @species_values);
    @species = sort {$species_defs->get_config($a, 'SPECIES_COMMON_NAME') 
                      cmp $species_defs->get_config($b, 'SPECIES_COMMON_NAME')} 
                @species;
    foreach my $sp (sort @species) {
      push @species_values, {'value' => $sp, 'name' => $species_defs->species_label($sp, 1)};
      my $mappings = $mappings{$sp};
      if ($mappings) {
        foreach my $string (reverse sort @$mappings) {
          my ($to, $from) = split('#', $string);
          ## Which mapping set? Have to fetch all, for easy JS auto-changing with species
          push @forward, {'name' => $from.' -> '.$to, 'value' => $from.':'.$to, 'class' => $sp};
          push @backward, {'name' => $to.' -> '.$from, 'value' => $to.':'.$from, 'class' => $sp};
        }
      }
    }

    $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'species',
      'label'   => "Species",
      'values'  => \@species_values,
      'value'   => $current_species,
      'select'  => 'select',
      'class'   => 'dropdown_remotecontrol',
    );

    my @values = (@forward, @backward);
    $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'conversion',
      'label'   => "Assembly/coordinates to convert",
      'values'  => \@values,
      'select'  => 'select',
      'class'   => 'conversion',
    );

    ## Check for uploaded data for this species
    my $user = $hub->user;
    if ($user) {
      my (@data, @temp);
      foreach my $upload ($user->uploads) {
        next unless $upload->species eq $species;
        push @data, $upload; 
      } 
      foreach my $upload ($session->get_data('type' => 'upload')) {
        next unless $upload->{'species'} eq $species;
        push @data, $upload;
      } 
      foreach my $url ($user->urls) {
        next unless $url->species eq $species;
        push @data, $url;
      } 
      foreach my $url ($session->get_data('type' => 'url')) {
        next unless $url->{'species'} eq $species;
        push @data, $url;
      } 
    
      if (@data) {
        $form->add_element('type' => 'SubHeader',
          'value' => 'Select existing upload(s)',
        );
        foreach my $file (@data) {
          my ($name, $id, $species);
          if (ref ($file) =~ /Record/) {
            my $type = $file->type;
            $name = $file->name;
            $id   = 'user-'.$type.'-'.$file->id; 
          }
          else {
            my $type = $file->{'type'};
            $name = $file->{'name'};
            $id   = 'temp-'.$type.'-'.$file->{'code'};
          }
          $form->add_element(
            'type'    => 'CheckBox',
            'name'    => 'convert_file',
            'label'   => $name,
            'value'   => $id.':'.$name,
          );
        }
        $subheader = 'Or upload new file';
      }
    }

    $form->add_element('type' => 'SubHeader', 'value' => $subheader);

    $form->add_element( type => 'String', name => 'name', label => 'Name for this upload (optional)' );

    $form->add_element( type => 'Text', name => 'text', label => 'Paste file' );
    $form->add_element( type => 'File', name => 'file', label => 'Upload file' );
    $form->add_element( type => 'URL',  name => 'url',  label => 'or provide file URL', size => 30 );

    $html .= $form->render;
  }
  else {
    $html .= $self->_info('No mappings', 'Sorry, no species currently have assembly mappings.');
  }
  return $html;
}

1;
