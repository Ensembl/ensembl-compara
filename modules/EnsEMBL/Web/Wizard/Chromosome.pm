package EnsEMBL::Web::Wizard::Chromosome;
                                                                                
use strict;
use warnings;
no warnings "uninitialized";
                                                                                
use EnsEMBL::Web::Wizard;
use EnsEMBL::Web::Form;
                                                                                
our @ISA = qw(EnsEMBL::Web::Wizard);
  
## DATA FOR DROPDOWNS, ETC.
        
## This wizard can accept multiple data sets, so we need 
## to keep track of this
our $tracks = 1;
                                                                        
sub _init {
  my ($self, $object) = @_;
                                                                                
  ## get useful data from object
  my @all_chr = @{$object->species_defs->ENSEMBL_CHROMOSOMES};
  my @chr_values;
  push @chr_values, {'name'=>'ALL', 'value'=>'ALL'} ;
  foreach my $next (@all_chr) {
    push @chr_values, {'name'=>$next, 'value'=>$next} ;
  }

  ## define other standard data
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

  my @styles = (
        {'group' => 'Density', 'value' => 'line', 'name' => 'Line graph'},
        {'group' => 'Density', 'value' => 'bar', 'name' => 'Bar chart, filled'},
        {'group' => 'Density', 'value' => 'outline', 'name' => 'Bar chart, outline'},
        {'group' => 'Location', 'value' => 'box', 'name' => 'Filled box'},
        {'group' => 'Location', 'value' => 'filledwidebox', 'name' => 'Filled wide box'},
        {'group' => 'Location', 'value' => 'widebox', 'name' => 'Outline wide box'},
        {'group' => 'Location', 'value' => 'outbox', 'name' => 'Oversize outline box'},
        {'group' => 'Location', 'value' => 'wideline', 'name' => 'Line'},
        {'group' => 'Location', 'value' => 'lharrow', 'name' => 'Arrow left side'},
        {'group' => 'Location', 'value' => 'rharrow', 'name' => 'Arrow right side'},
        {'group' => 'Location', 'value' => 'bowtie', 'name' => 'Arrows both sides'},
        {'group' => 'Location', 'value' => 'text', 'name' => 'Text label (+ wide box)'},
  );

  my $data = {
    'loops'         => $tracks,
    'chr_values'    => \@chr_values,
    'colours'       => \@colours,
    'styles'        => \@styles,
  };
                                                                                
  return $data;

}
                                                                              
## define fields available to the forms in this wizard
our %form_fields = (
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

sub default_order {
  my @order = qw(chr rows chr_length h_padding h_spacing v_padding track_name style col paste_file upload_file url_file);
  return \@order;
}

## define the nodes available to wizards based on this type of object
our %all_nodes = (
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
      'page' => 1,
  },
);

## Accessor methods for standard data
sub form_fields { return %form_fields; }
sub get_node { return $all_nodes{$_[1]}; }

## ---------------------- METHODS FOR INDIVIDUAL NODES ----------------------


sub kv_add {
  my ($self, $object) = @_;
                                                                                
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'kv_add';           
      
  ## rewrite node values if we are re-doing this page for an additional track
  my $tracks = $wizard->attrib('loops');
  if ($object->param('submit_kv_add') eq 'Add more data >') {
    push @{$all_nodes{'kv_add'}{'pass_fields'}}, 
      ("track_name_$tracks", "style_$tracks", "col_$tracks",
      "paste_file_$tracks", "upload_file_$tracks", "url_file_$tracks",
      "merge_$tracks");
    $all_nodes{'kv_add'}{'back'} = 1;
    $tracks++;
    $wizard->attrib('loops', $tracks);
  }
                                                               
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');

  ## show previously-added tracks
  if ($object->param('style_1')) {
    my $plural = 's' if $tracks > 1;
    $form->add_element(
      'type'   => 'SubHeader',
      'value'  => qq(Track$plural added so far:),
    );
    my @cols   = @{$wizard->attrib('colours')};
    my @styles = @{$wizard->attrib('styles')};
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
  $wizard->add_buttons($node, $form, $object);
                                                                                
  return $form;
}

sub kv_extras {
  my ($self, $object) = @_;
                                                                                
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'kv_extras';

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
    push @{$all_nodes{'kv_extras'}{'input_fields'}}, 'maxmin' 
      unless grep {$_ eq 'maxmin'} @{$all_nodes{'kv_extras'}{'input_fields'}};
  }
  if ($location) {
    push @{$all_nodes{'kv_extras'}{'input_fields'}}, 'zmenu' 
      unless grep {$_ eq 'zmenu'} @{$all_nodes{'kv_extras'}{'input_fields'}};
  }
                                                                                
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');
                                                                                
  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
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
  ## this node doesn't actually do anything 'wizardy', it just 
  ## displays the data using the corresponding Component method
  return 1;
}

1;
