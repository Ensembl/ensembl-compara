package EnsEMBL::Web::Wizard::Chromosome;
                                                                                
use strict;
use warnings;
no warnings "uninitialized";
                                                                                
use EnsEMBL::Web::Wizard;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::File::Text;
                                                                                
our @ISA = qw(EnsEMBL::Web::Wizard);
  

sub add_karyotype_options {
  my ($self, $object, $option) = @_;
  
  ## chromosome numbers
  my @all_chr = @{$object->species_defs->ENSEMBL_CHROMOSOMES};
  my @chr_values = ({'name'=>'ALL', 'value'=>'ALL'}) ;
  foreach my $next (@all_chr) {
    push @chr_values, {'name'=>$next, 'value'=>$next} ;
  }

  ## pointer/track styles
  my @colours = (
        {'value' => 'purple',   'name'=> 'Purple'},
        {'value' => 'magenta',  'name'=> 'Magenta'},
        {'value' => 'red',      'name' =>'Red'},
        {'value' => 'orange',   'name' => 'Orange'},
        {'value' => 'brown',    'name'=> 'Brown'},
        {'value' => 'green',    'name'=> 'Green'},
        {'value' => 'darkgreen','name'=> 'Dark Green'},
        {'value' => 'blue',     'name'=> 'Blue'},
        {'value' => 'darkblue', 'name'=> 'Dark Blue'},
        {'value' => 'violet',   'name'=> 'Violet'},
        {'value' => 'grey',     'name'=> 'Grey'},
        {'value' => 'darkgrey', 'name'=> 'Dark Grey'}
  );

  my %all_styles = (
    'density' => [
        {'value' => 'line', 'name' => 'Line graph'},
        {'value' => 'bar', 'name' => 'Bar chart, filled'},
        {'value' => 'outline', 'name' => 'Bar chart, outline'},
    ],
    'location' => [
        {'value' => 'box', 'name' => 'Filled box'},
        {'value' => 'filledwidebox', 'name' => 'Filled wide box'},
        {'value' => 'widebox', 'name' => 'Outline wide box'},
        {'value' => 'outbox', 'name' => 'Oversize outline box'},
        {'value' => 'wideline', 'name' => 'Line'},
        {'value' => 'lharrow', 'name' => 'Arrow left side'},
        {'value' => 'rharrow', 'name' => 'Arrow right side'},
        {'value' => 'bowtie', 'name' => 'Arrows both sides'},
        {'value' => 'text', 'name' => 'Text label (+ wide box)'},
    ],
  );

  my @styles;
  my $style_opt = $option->{'styles'};
  if (ref($style_opt) eq 'ARRAY') {
    foreach my $style_gp (@{$style_opt}) {
      my $group = $all_styles{$style_gp};
      if ($group) {
        my $group_name = ucfirst($style_gp);
        foreach my $style (@$group) {
          $style->{'group'} = $group_name if $option->{'group_styles'}; ## for OPTGROUP
          push(@styles, $style);
        }
      } 
    }
  }

  ## basic widgets to configure karyotype
  ## N.B. Don't include styles and colours as depends on number of tracks being done 
  my %widgets = (
    'track_subhead' => {
      'type' => 'SubHeader',
      'value' => 'Feature graphics',
    },
    'layout_subhead' => {
      'type' => 'SubHeader',
      'value' => 'Karyotype layout',
    },
    'chr'   => {
      'type'=>'DropDown',
      'select'   => 'select',
      'label'=>'Chromosome',
      'required'=>'yes',
      'values' => 'chr_values',
    },
    'rows'    => {
      'type'=>'Int',
      'label'=>'Number of rows of chromosomes',
      'value' => '2',
      'required'=>'yes',
    },
    'chr_length' => {
      'type'=>'Int',
      'label'=>'Height of the longest chromosome (pixels)',
      'value' => '200',
      'required'=>'yes',
    },
    'h_padding' => {
      'type'=>'Int',
      'label'=>'Padding around chromosomes (pixels)',
      'value' => '4',
      'required'=>'yes',
    },
    'h_spacing'    => {
      'type'=>'Int',
      'label'=>'Spacing between chromosomes (pixels)',
      'value' => '6',
      'required'=>'yes',
    },
    'v_padding'    => {
      'type'=>'Int',
      'label'=>'Spacing between rows (pixels)',
      'value' => '50',
      'required'=>'yes',
    },
  );
  return (\@chr_values, \@colours, \@styles, \%widgets);
}

## This wizard can accept multiple data sets, so we need 
## to keep track of this
our $tracks = 1;

sub _init {
  my ($self, $object) = @_;

  ## define fields available to the forms in this wizard
  my %form_fields = (
    'blurb' => {
      'type'  => 'Information',
      'value' => qq(Karyoview now allows you to display multiple data sets as either density plots, location pointers or a mixture of the two. Add all your data sets first, then click on 'Continue' for more configuration options.),
    },
    'track_name'  => {
      'type'=>'String',
      'label'=>'Track name (optional)',
      'loop'=>1,
    },
    'style'       => {
      'type'=>'DropDown',
      'select'   => 'select',
      'label'=>'Style',
      'required'=>'yes',
      'values' => 'styles',
      'loop'=>1,
    },
    'col'       => {
      'type'=>'DropDown',
      'select'   => 'select',
      'label'=>'Colour',
      'required'=>'yes',
      'values' => 'colours',
      'loop'=>1,
    },
    'paste_file' => {
      'type'=>'Text',
      'label'=>'Paste file content',
      'loop'=>1,
    },
    'upload_file' => {
      'type'=>'File',
      'label'=>'Upload file',
      'loop'=>1,
    },
    'url_file' => {
      'type'=>'String',
      'label'=>'File URL',
      'loop'=>1,
    },
    'merge'  => {
      'type'  => 'CheckBox',
      'label' => 'Merge features into a single track',
      'loop'=>1,
      'value' => 'on',
    },
    'extras_subhead'  => {
      'type'  => 'SubHeader',
      'value' => 'Add Ensembl tracks',
    },
    'track_Vpercents'  => {
      'type'  => 'CheckBox',
      'label' => 'Show GC content frequency *',
      'value' => 'on',
    },
    'track_Vsnps'  => {
      'type'  => 'CheckBox',
      'label' => 'Show SNP frequency *',
      'value' => 'on',
    },
    'track_Vgenes'  => {
      'type'  => 'CheckBox',
      'label' => 'Show gene frequency *',
      'value' => 'on',
    },
    'track_blurb' => {
      'type'  => 'Information',
      'value' => '* Extra tracks will only be shown if you select a single chromosome to display on your karyotype',
    },
    'maxmin'  => {
      'type'  => 'CheckBox',
      'label' => 'Show max/min lines',
      'value' => 'on',
    },
    'zmenu'  => {
      'type'  => 'CheckBox',
      'label' => 'Display mouseovers on menus',
      'value' => 'on',
    },
);

  ## define the nodes available to wizards based on this type of object
  my %all_nodes = (
    'kv_add' => {
      'form' => 1,
      'title' => 'Add your data',
      'input_fields'  => [qw(blurb track_name style col merge paste_file upload_file url_file)],
      'button'  => 'Add more data',
    },
    'kv_extras' => {
      'form' => 1,
      'title' => 'Add extra features',
      'input_fields'  => [qw(extras_subhead track_Vpercents track_Vsnps track_Vgenes track_blurb)],
      'no_passback' => [qw(style)],
      'button' => 'Continue',
      'back'   => 1,
    },
    'kv_layout' =>  {
      'form' => 1,
      'title' => 'Configure karyotype',
      'input_fields'  => [qw(chr rows chr_length h_padding h_spacing v_padding)],
      'button' => 'Continue',
      'back'   => 1,
    },
    'kv_display'  => {
      'button' => 'Finish',
      'form' => 1,
    },
  );

  ## get useful data from object
 ## add generic karyotype stuff
  my $option = {
    'styles' => ['density', 'location'],
    'group_styles' => 1,
  };
  my ($chr_values, $colours, $styles, $widgets) = $self->add_karyotype_options($object, $option);
  my %all_fields = (%form_fields, %$widgets);

  my $data = {
    'loops'         => $tracks,
    'chr_values'    => $chr_values,
    'colours'       => $colours,
    'styles'        => $styles,
  };

  return [$data, \%all_fields, \%all_nodes];

}
                                                                              
## ---------------------- METHODS FOR INDIVIDUAL NODES ----------------------


sub kv_add {
  my ($self, $object) = @_;
                                                                                
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'kv_add';           
      
  ## cache uploaded file
  my $track_id = $wizard->data('loops');
  my $upload = $object->param("upload_file_$track_id");
  my $cache = _fh_cache($self, $object, $upload) if $upload;

  ## rewrite node values if we are re-doing this page for an additional track
  if ($object->param('submit_kv_add') eq 'Add more data >') {
    $self->redefine_node('kv_add', 'pass_fields', 
      ["track_name_$tracks", "style_$tracks", "col_$tracks",
      "paste_file_$tracks", "upload_file_$tracks", "url_file_$tracks",
      "merge_$tracks"]);
    $self->redefine_node('kv_add', 'back', 1);
    $tracks++;
    $wizard->data('loops', $tracks);
  }
                                                               
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');

  ## show previously-added tracks
  if ($object->param('style_1')) {
    my $plural = 's' if $tracks > 1;
    $form->add_element(
      'type'   => 'SubHeader',
      'value'  => qq(Track$plural added so far:),
    );
    my @cols   = @{$wizard->data('colours')};
    my @styles = @{$wizard->data('styles')};
    my ($colour, $style, $h_ref, %hash, $output);
    for (my $i = 0; $i < $tracks; $i++) {
      my $track_name = $object->param("track_name_$i");
      $output = "$track_name: " if $track_name;
      foreach $h_ref (@cols) {
        %hash = %$h_ref;
        $colour = lc($hash{'name'}) if $hash{'value'} eq $object->param("col_$i");
      }
      foreach $h_ref (@styles) {
        %hash = %$h_ref;
        $style = lc($hash{'name'}) if $hash{'value'} eq $object->param("style_$i");
      }
      $output .= "$colour $style";
      $form->add_element(
        'type'   => 'Information',
        'value'  => $output,
      );
    }
  }

  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  if ($upload) {
    $form->add_element(
      'type'   => 'Hidden',
      'name'   => "cache_file_$track_id",
      'value'  => $cache,
    );
  }
  $wizard->add_buttons($node, $form, $object);
                                                                                
  return $form;
}

sub _fh_cache {
  ## make a copy of the uploaded temp file so we can get at it later
  my ($self, $object, $filename) = @_;

  my $cgi = $object->[1]->{'_input'}; 
  my $tmpfilename = $cgi->tmpFileName($filename);

  my $cache = new EnsEMBL::Web::File::Text($object->[1]->{'_species_defs'});
  $cache->set_cache_filename($tmpfilename);
  $cache->save($tmpfilename);
  my $cachename = $cache->filename;
  return $cachename;
}

sub kv_extras {
  my ($self, $object) = @_;
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'kv_extras';
               
  ## cache uploaded file
  my $track_id = $wizard->data('loops');
  my $upload = $object->param("upload_file_$track_id");
  my $cache = _fh_cache($self, $object, $upload) if $upload;

  ## add appropriate options
  my ($location, $density);
  my @params = $object->param;
  foreach my $param (@params) {
    next unless $param =~ /^style/;
    if ($object->param($param) =~ /bar|line|outline/) {
      $density = 1;
    }
    else {
      $location = 1;
    }
  }
  if ($density) {
    $wizard->redefine_node('kv_extras', 'input_fields', ['maxmin']); 
  }
  if ($location) {
    $wizard->redefine_node('kv_extras', 'input_fields', ['zmenu']); 
  }
                                                                                
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');
                                                                                
  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  if ($upload) {
    $form->add_element(
      'type'   => 'Hidden',
      'name'   => "cache_file_$track_id",
      'value'  => $cache,
    );
  }
  $wizard->add_buttons($node, $form, $object);
                                                                                
  return $form;
}

sub kv_layout {
  my ($self, $object) = @_;
                                                                                
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'kv_layout';
                                                                                
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');
                                                                                
  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);
                                                                                
  return $form;
}

sub kv_display {
  my ($self, $object) = @_;
                                                                                
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'kv_display';
                                                                                
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');

  $wizard->redefine_node('kv_add', 'button', 'Reconfigure this display');
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);
                                                                                
  return $form;
}

1;
