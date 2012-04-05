# $Id$

package EnsEMBL::Web::Component::UserData::SelectFeatures;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self              = shift;
  my $hub               = $self->hub;
  my $session           = $hub->session;
  my $species_defs      = $hub->species_defs;
  my $species           = $hub->data_species;
  my @valid_species     = $species_defs->valid_species;
  my %assembly_mappings = map { $_ => $species_defs->get_config($_, 'ASSEMBLY_MAPPINGS') } @valid_species;
  my @mapping_species   = sort grep $assembly_mappings{$_}, @valid_species;
  my $html;

  if (scalar @mapping_species) {
    my $user      = $hub->user;
    my $subheader = 'Upload file';
    my $form      = $self->modal_form('select', $hub->url({ action => 'CheckConvert', __clear => 1 }));
    my (@forward, @backward, @species_values);
    
    $form->add_notes({
      heading => 'Tips',
      text    => qq{
        <p class="space-below">
          Map your data to the current assembly. 
          The tool accepts a <a href="/info/website/upload/bed.html#required">list of simple coordinates</a>, 
          or files in these formats: 
          <a href="/info/website/upload/gff.html">GFF</a>,
          <a href="/info/website/upload/gff.html">GTF</a>,
          <a href="/info/website/upload/bed.html">BED</a>,
          <a href="/info/website/upload/psl.html">PSL</a>
        </p>
        <p class="space-below">N.B. Export is currently in GFF only</p>
        <p>For large data sets, you may find it more efficient to use our <a href="http://cvs.sanger.ac.uk/cgi-bin/viewvc.cgi/ensembl-tools/scripts/assembly_converter/?root=ensembl">ready-made converter script</a>.</p>
      }
    });
    
    ## Munge data needed for form elements
    foreach (@mapping_species) {
      push @species_values, { value => $_, name => $species_defs->species_label($_, 1) };
     
      my @mappings = ref($assembly_mappings{$_}) eq 'ARRAY' ? @{$assembly_mappings{$_}} : ($assembly_mappings{$_});
 
      foreach my $string (sort { $b cmp $a } @mappings) {
        my ($to, $from) = split '#', $string;
        ## Which mapping set? Have to fetch all, for easy JS auto-changing with species
        push @forward,  { name => "$from -> $to", value => "${from}:$to", class => $_ };
        push @backward, { name => "$to -> $from", value => "${to}:$from", class => $_ };
      }
    }

    $form->add_element(
      type   => 'DropDown',
      name   => 'species',
      label  => 'Species',
      values => \@species_values,
      value  => $species,
      select => 'select',
      class  => 'dropdown_remotecontrol',
    );
    
    $form->add_element(
      type   => 'DropDown',
      name   => 'conversion',
      label  => 'Assembly/coordinates to convert',
      values => [ @forward, @backward ],
      select => 'select',
      class  => 'conversion',
    );

    ## Check for uploaded data for this species
    my @data = grep { $_->{'species'} eq $species } map { $user ? $user->$_ : (), $session->get_data(type => substr $_, 0, -1) } qw(uploads urls);
  
    if (scalar @data) {
      $form->add_element(type => 'SubHeader', value => 'Select existing upload(s)');
      
      $subheader = 'Or upload new file';
      
      foreach my $file (@data) {
        my ($name, $id) = ref($file) =~ /Record/ ? ($file->name, join('-', 'user', $file->type, $file->id)) : ($file->{'name'}, "temp-$file->{'type'}-$file->{'code'}");
        
        $form->add_element(
          type  => 'CheckBox',
          name  => 'convert_file',
          label => $name,
          value => "${id}:$name",
        );
      }
    }

    $form->add_element(type => 'SubHeader', value => $subheader);
    $form->add_element(type => 'Hidden', name => 'filetype', value => 'Assembly Converter');
    $form->add_element(type => 'String', name => 'name', label => 'Name for this upload (optional)');
    $form->add_element(type => 'Text',   name => 'text', label => 'Paste file');
    $form->add_element(type => 'File',   name => 'file', label => 'Upload file');
    $form->add_element(type => 'URL',    name => 'url',  label => 'or provide file URL', size => 30);
    
    $html .= '<input type="hidden" class="panel_type" value="AssemblyMappings" />';
    $html .= $form->render;
  } else {
    $html .= $self->_info('No mappings', 'Sorry, no species currently have assembly mappings.');
  }
  
  return $html;
}

1;
