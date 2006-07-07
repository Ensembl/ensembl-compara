package EnsEMBL::Web::Wizard::News;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Wizard;
use EnsEMBL::Web::Form;

our @ISA = qw(EnsEMBL::Web::Wizard);

## DATA FOR DROPDOWNS, ETC.

sub _init {
  my ($self, $object) = @_;

  ## get useful data from object

  ## default/current record (if available)
  my $record;
  if ($object->param('news_item_id')) {
    my @items = @{$object->items};
    foreach my $item (@items) {
        my %item = %$item;
        my $code = $item{'news_item_id'};
        next unless $code eq $object->param('news_item_id');
        $record = $item;
    } 
  }
  ## array of release names and values
  my @releases = @{$object->releases};
  my @rel_values;
  foreach my $release (@releases) {
    my $id = $$release{'release_id'};
    my $date = $$release{'release_number'}.' ('.$$release{'short_date'}.')';
    push (@rel_values, {'name'=>$date,'value'=>$id});
  }

  ## array of valid species names and values
  my %valid_species = %{$object->valid_spp};
  my @sorted = sort {$valid_species{$a} cmp $valid_species{$b}} keys %valid_species;
  my @spp_values;
  foreach my $id (@sorted) {
    my $name = $valid_species{$id};
    $name =~ s/_/ /g;
    push (@spp_values, {'name'=>$name,'value'=>$id});
  }

  ## array of category names and values
  my @categories = @{$object->all_cats};
  my @cat_values;
  foreach my $cat (@categories) {
    my $id = $$cat{'news_cat_id'};
    my $name = $$cat{'news_cat_name'};
    push (@cat_values, {'name'=>$name,'value'=>$id});
  }

  ## array of status names and values
  my @stat_values = (
                        {'name'=>'Draft', 'value'=>'draft'},
                        {'name'=>'Live',  'value'=>'live'},
                        {'name'=>'Dead',  'value'=>'dead'},
  );

  my $data = {
    'record'      => $record,
    'rel_values'  => \@rel_values,
    'spp_values'  => \@spp_values,
    'cat_values'  => \@cat_values,
    'stat_values' => \@stat_values,
  };

  return $data;
}

## define fields available to the forms in this wizard
our %form_fields = (
      'release_id'      => {
          'type'=>'DropDown',
          'select'   => 'select', 
          'label'=>'Release', 
          'required'=>'yes',
          'values' => 'rel_values',
      },
      'species'         => {
          'type'=>'MultiSelect', 
          'label'=>'Species',
          'required'=>'yes',
          'values' => 'spp_values',
      },
      'news_cat_id'     => {
          'type'=>'DropDown', 
          'select'   => 'select', 
          'label'=>'Category',
          'required'=>'yes',
          'values' => 'cat_values',
      },
      'status'          => {
          'type'=>'DropDown', 
          'select'   => 'select', 
          'label'=>'Publication Status',
          'required'=>'yes',
          'values' => 'stat_values',
      },
      'priority'        => {
          'type'=>'PosInt',
          'label'=>'Priority [0-5]',
          'required'=>'yes',
      },
      'title'           => {
          'type'=>'String', 
          'label'=>'Title',
          'required'=>'yes',
      },
      'content'         => {
          'type'=>'Text', 
          'label'=>'Content',
          'required'=>'yes',
      },
);
 
sub default_order {
  my @order = qw(release_id species news_cat_id status priority title content);
  return \@order;
}

## define the nodes available to wizards based on this type of object
our %all_nodes = (
     'which_rel'      => {
                      'form' => 1,
                      'title' => 'Select a release',
                      'input_fields'  => [qw(release_id)], 
      },
     'select'      => {
                      'form' => 1,
                      'title' => 'Select a news item',
                      'pass_fields'  => [qw(release_id)], 
      },
     'enter'      => {
                      'form' => 1,
                      '' => 1,
                      'title' => 'Enter item details',
                      'show_fields'  => [qw(release_id)], 
                      'input_fields' => [qw(species news_cat_id status priority title content)],
                      'pass_fields'  => [qw(news_item_id release_id)], 
      },
     'preview'      => {
                      'form' => 1,
                      'title' => 'Please check the entry',
                      'pass_fields'  => [qw(news_item_id release_id species news_cat_id status priority title content)], 
                      'back' => 1,
                      'button' => 'Preview',
      },
      'save'        => {'button'=>'Save'},
     'pub_select'      => {
                      'form' => 1,
                      'title' => 'Select a news item and database',
                      'pass_fields'  => [qw(release_id)], 
      },
     'pub_preview'  => {
                      'form' => 1,
                      'title' => 'Please check the entry',
                      'pass_fields'  => [qw(news_item_id release_id species news_cat_id status priority title content)], 
                      'back' => 1,
                      'button' => 'Preview',
      },
      'pub_save'        => {'button'=>'Publish'},
);

our %message = (
  'save_ok'     => 'Thank you. Your changes have been saved.',
  'save_failed' => 'Sorry, there was a problem saving your changes to the database.',

);

## Accessor methods for standard data
sub form_fields { return %form_fields; }
sub get_node { return $all_nodes{$_[1]}; }
sub get_message { return $message{$_[1]}; }


## ---------------------- METHODS FOR INDIVIDUAL NODES ----------------------

sub which_rel {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  
  my $form = EnsEMBL::Web::Form->new('which_rel', "/$species/$script", 'post');

  $wizard->simple_form('which_rel', $form, $object, 'input');

  return $form;
}

sub select {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
 
  my $form = EnsEMBL::Web::Form->new( 'select', "/$species/$script", 'post' );

  ## Do custom widget showing title, species and status for each news item
  my $item_values = _story_select($object);
  if ($item_values) { 
    $form->add_element(
      'type'     => 'DropDown',
      'select'   => 'select',
      'required' => 'yes',
      'name'     => 'news_item_id',
      'label'    => 'News item',
      'values'   => $item_values,
    );
  }
  
  $wizard->pass_fields('select', $form, $object);
  $wizard->add_buttons('select', $form, $object);

  return $form;
}

sub _story_select {
  my $object = shift;

  my @sp_items = @{$object->species_items}; 
  my @gen_items = @{$object->generic_items}; 
  my @items = (@sp_items, @gen_items); 
  @items = @{ $object->sort_items(\@items) }; 
  my %all_spp = %{$object->all_spp};
  my @all_rels = @{$object->releases};
  my @item_values;
  if (scalar(@items) > 0 ) { ## sanity check!
    foreach my $item (@items) {
        my %item = %$item;
        my $code = $item{'news_item_id'};
        my $species_count = 0;
        if (ref($item{'species'})) {
            $species_count = scalar(@{$item{'species'}});
        }
        my $sp_name;
        if ($species_count != 1) {
            $sp_name = 'multi-species';
        }
        else {
            my @sp_array = @{$item{'species'}};
            $sp_name = $all_spp{$sp_array[0]};
        }
         my $release_number;
        foreach my $rel (@all_rels) {
            if ($item{'release_id'} == $$rel{'release_id'}) {
                $release_number = $$rel{'release_number'};
            }
        }
        my $status = $item{'status'};
        my $name = 'Rel '.$release_number.' - '.$item{'title'}." ($sp_name)";
        $name .= ' ['.uc($status).']' if $status ne 'live';
        push (@item_values, {'name'=>$name,'value'=>$code});
    }
    return \@item_values;
  }
  else {
    return 0;
  }
}

sub enter {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};

  my $script = $object->script;
  my $species = $object->species;
  if (!$object->param('release_id')) {
    my $current = $object->species_defs->ENSEMBL_VERSION;
    $object->param('release_id', $current);
  }
  
  my $form = EnsEMBL::Web::Form->new( 'enter', "/$species/$script", 'post' );

  my $node = 'enter';
  $wizard->add_title($node, $form, $object);
  $wizard->show_fields($node, $form, $object);
  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);

  return $form;
}

sub preview {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  
  my $form = EnsEMBL::Web::Form->new( 'preview', "/$species/$script", 'post' );

  $wizard->simple_form('preview', $form, $object, 'output');

  return $form;
}

sub save {
  my ($self, $object) = @_;
  my %parameter; 

  ## note - no need to define node if going back to beginning of wizard
  my $record = $self->create_record($object);
  my $result = $object->save_to_db($record);
  if ($result) { 
    $parameter{'feedback'} = 'save_ok';
  }
  else {
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'save_failed';
  }

  return \%parameter;
}

#------ News Publishing nodes -----------------------------------------------

sub pub_select {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
 
  my $form = EnsEMBL::Web::Form->new( 'pub_select', "/$species/$script", 'post' );

  ## Do custom widget showing title, species and status for each news item
  my $item_values = _story_select($object);
  if ($item_values) { 
    $form->add_element(
      'type'     => 'DropDown',
      'select'   => 'select',
      'required' => 'yes',
      'name'     => 'news_item_id',
      'label'    => 'News item',
      'values'   => $item_values,
    );
  }
  
  ## do database select widget
  $form->add_element(
    'type'  => 'Information',
    'value' => 'Choose a database to publish to',
  );

  $wizard->pass_fields('pub_select', $form, $object);
  $wizard->add_buttons('pub_select', $form, $object);

  return $form;
}

sub pub_preview {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  
  my $form = EnsEMBL::Web::Form->new( 'pub_preview', "/$species/$script", 'post' );

  $wizard->simple_form('pub_preview', $form, $object, 'output');

  return $form;
}

sub pub_save {
  my ($self, $object) = @_;
  my %parameter; 

  ## note - no need to define node if going back to beginning of wizard
  my $record = $self->create_record($object);
  my $result = $object->save_to_db($record);
  if ($result) { 
    $parameter{'feedback'} = 'save_ok';
  }
  else {
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'save_failed';
  }

  return \%parameter;
}

sub multi_select {
}

1;

__END__
                                                                                
=head1 EnsEMBL::Web::Wizard::News

=head2 SYNOPSIS

See E::W::Configuration::News for examples of how to use the wizard.

=head2 DESCRIPTION

Wizard module containing nodes and form data for managing the news section of the Ensembl web database.

=head2 METHODS                                                                                
=head3 B<which_rel>
                                                                                
Description: Creates the release selection form

Arguments: E::W::Configuration object), E::W::Proxy::Object object (News)    
                                                                                
Returns:  E::W::Form object

=head3 B<select>
                                                                                
Description: Creates the news item selection form

Arguments: E::W::Configuration object), E::W::Proxy::Object object (News)    
                                                                                
Returns:  E::W::Form object

=head3 B<enter>
                                                                                
Description: Creates the main data entry form for a news record

Arguments: E::W::Configuration object), E::W::Proxy::Object object (News)    
                                                                                
Returns:  E::W::Form object

=head3 B<preview>
                                                                                
Description: Creates a hidden form to display and passes the record being added/edited

Arguments: E::W::Configuration object), E::W::Proxy::Object object (News)    
                                                                                
Returns:  E::W::Form object

=head3 B<save>
                                                                                
Description: Saves changes to the ensembl_website database and returns parameters telling the wizard which node to redirect to and any error messages/feedback for the user

Arguments: E::W::Configuration object), E::W::Proxy::Object object (News)    
                                                                                
Returns:  reference to a hash

=head2 BUGS AND LIMITATIONS
                                                                                
=head2 AUTHOR
                                                                                
Anne Parker, Ensembl Web Team
Support enquiries: helpdesk\@ensembl.org
                                                                                
=head2 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html
                                                                                
=cut                                                                  

                                                                                
