package EnsEMBL::Web::Component::News;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;

use strict;
use warnings;
no warnings "uninitialized";

@EnsEMBL::Web::Component::News::ISA = qw( EnsEMBL::Web::Component);

#-----------------------------------------------------------------
# NEWSVIEW COMPONENTS    
#-----------------------------------------------------------------

#-----------------------------------------------------------------
# NEWSDBVIEW COMPONENTS    
#-----------------------------------------------------------------

sub select_news {
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);

  if ($object->param('action') eq 'saved') {
    $html .= "<p>Thank you. Your changes have been saved to the database.</p>";
  }

  $html .= $panel->form( 'select_item' )->render();
  $html .= $panel->form( 'select_release' )->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;

}

sub select_item_form {
  my( $panel, $object ) = @_;
  my $script = $object->script;
  my $species = $object->species;
  my $form = EnsEMBL::Web::Form->new( 'select_item', "/$species/$script", 'post' );
  
  # create array of release numbers, species and story titles
  my @items = @{$object->items};
  my %all_spp = %{$object->all_spp};
  my @all_rels = @{$object->releases};
  if (scalar(@items) > 0 ) { # sanity check!

    my @item_values;
    foreach my $item (@items) {
        my %item = %$item;
        my $code = $item{'news_item_id'};
        my $species_count = scalar(@{$item{'species'}});
        my $sp_name;
        if ($species_count > 1) {
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
        my $name = 'Rel '.$release_number.' - '.$item{'title'}." ($sp_name)";
        push (@item_values, {'name'=>$name,'value'=>$code});
    }
 
    $form->add_element( 'type' => 'SubHeader', 'value' => 'Select a news item from the latest release');
    $form->add_element( 'type' => 'Information', 'value' => '(to add an item, click on the menu link, left)');
    $form->add_element(
    'type'     => 'DropDown',
    'select'   => 'select',
    'required' => 'yes',
    'name'     => 'news_item_id',
    'label'    => 'News item',
    'values'   => \@item_values,
  );
    $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Edit');
  }
  else {
    $form->add_element( 'type' => 'SubHeader', 'value' => 'Release '.$object->param('release'));
    $form->add_element( 'type' => 'Information', 'value' => 'There are currently no news items for this release. Please try another one.');
  }  
  return $form ;
}

sub select_release_form {
  my( $panel, $object ) = @_;
  my $script = $object->script;
  my $species = $object->species;
  
  # create array of release numbers and dates
  my @releases = @{$object->releases};
  my @rel_values;
  foreach my $rel (@releases) {
    my $id = $$rel{'release_id'};
    my $text = 'Release '.$$rel{'release_number'}.', '.$$rel{'date'};
    push (@rel_values, {'name'=>$text,'value'=>$id});
  }
 
  my $form = EnsEMBL::Web::Form->new( 'select_item', "/$species/$script", 'post' );
  
  $form->add_element( 'type' => 'SubHeader', 'value' => 'Select a previous release');
  $form->add_element(
    'type'     => 'DropDown',
    'select'   => 'select',
    'required' => 'yes',
    'name'     => 'release_id',
    'label'    => 'Release',
    'values'   => \@rel_values,
  );

  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Next');
  return $form ;
}

#-----------------------------------------------------------------

sub item_form {
                                                                                
  my ($form, $object) = @_;
  my ($id, $name, $date);
                                                                                
  # set default values for form
  my ($title, $content, $release_id);
  my $release = $object->species_defs->ENSEMBL_VERSION;
  my $news_cat_id = 2; # data
  my $species = [1]; # human
  my $priority = 0;

  if (scalar(@{$object->items}) == 1) { # have already selected a single item
    my %item = %{${$object->items}[0]};
    $title = $item{'title'};
    $content = $item{'content'};
    $release_id = $item{'release_id'};
    $news_cat_id = $item{'news_cat_id'};
    $species = $item{'species'};
    $priority = $item{'priority'};
  }

  # create array of release names and values
  my @releases = @{$object->releases};
  my @rel_values;
  foreach my $release (@releases) {
    $id = $$release{'release_id'};
    $date = $$release{'release_number'}.' ('.$$release{'date'}.')';
    push (@rel_values, {'name'=>$date,'value'=>$id});
  }
                                                                                
  # create array of species names and values
  my %all_species = %{$object->all_spp};
  my @sorted = sort {$all_species{$a} cmp $all_species{$b}} keys %all_species;
  my @spp_values;
  foreach my $id (@sorted) {
    my $name = $all_species{$id};
    push (@spp_values, {'name'=>$name,'value'=>$id});
  }

  # create array of category names and values
  my @categories = @{$object->all_cats};
  my @cat_values;
  foreach my $cat (@categories) {
    $id = $$cat{'news_cat_id'};
    $name = $$cat{'news_cat_name'};
    push (@cat_values, {'name'=>$name,'value'=>$id});
  }
                                                                                
  $form->add_element(
    'type'     => 'DropDown',
    'select'   => 'select',
    'required' => 'yes',
    'name'     => 'release_id',
    'label'    => 'Release',
    'values'   => \@rel_values,
    'value'    => $release_id,
  );

  $form->add_element(
    'type'     => 'MultiSelect',
    'required' => 'yes',
    'name'     => 'species',
    'label'    => 'Species',
    'values'   => \@spp_values,
    'value'    => $species,
  );
  $form->add_element(
    'type'     => 'DropDown',
    'select'   => 'select',
    'required' => 'yes',
    'name'     => 'news_cat_id',
    'label'    => 'News Category',
    'values'   => \@cat_values,
    'value'    => $news_cat_id,
  );
  $form->add_element(
    'type'     => 'Int',
    'required' => 'yes',
    'name'     => 'priority',
    'label'    => 'Priority [0-5]',
    'value'    => $priority,
    'size'     => '1'
  );
  $form->add_element(
    'type'      => 'String',
    'name'      => 'title',
    'label'     => 'Title',
    'value'     => $title
  );
   $form->add_element(
    'type'   => 'Text',
    'name'   => 'content',
    'label'  => 'Content',
    'value'  => $content,
  );
  $form->add_element( 'type' => 'Hidden', 'name' => 'update', 'value' => 'yes');

}

sub edit_item {
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form( 'edit_item' )->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
                                                                                
}

sub edit_item_form {
                                                                                
  my( $panel, $object ) = @_;
  my $species = $object->species;
  my $script = $object->script;
  my $id = $object->param('news_item_id');
                                                                                
  my $form = EnsEMBL::Web::Form->new( 'edit_item', "/$species/$script", 'post' );
  $form->add_element( 'type' => 'SubHeader', 'value' => 'Edit a news item');
  item_form($form, $object);
  $form->add_element( 'type' => 'Hidden', 'name' => 'news_item_id', 'value' => $id);
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Preview');
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Save Changes');
  return $form ;
}

sub add_item {
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form( 'add_item' )->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
                                                                                
}

sub add_item_form {
                                                                                
  my( $panel, $object ) = @_;
  my $species = $object->species;
  my $script = $object->script;
                                                                                
  my $form = EnsEMBL::Web::Form->new( 'add_item', "/$species/$script", 'post' );
  $form->add_element( 'type' => 'SubHeader', 'value' => 'Add a news item');
  item_form($form, $object);
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Preview');
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Save Changes');
  return $form ;
}

#-----------------------------------------------------------------

sub preview_item {
  my ( $panel, $object ) = @_;
  my %all_species = %{$object->all_spp};
  my @releases = @{$object->releases};
                                                                                
  my %item = %{@{$object->items}[0]};
  my $title = $item{'title'};
  my $content = $item{'content'};
  my $release_id = $item{'release_id'};
  my $news_cat_name = $item{'news_cat_name'};
  my $species = $item{'species'};
  my $priority = $item{'priority'};

  my $species_list = '<ul>';
  foreach my $sp (@$species) {
    my $sp_name = $all_species{$sp};
    $species_list .= "<li>$sp_name</li>";
  }
  $species_list .= '</ul>';

  my $release_number;
  foreach my $rel (@releases) {
    if ($release_id == $$rel{'release_id'}) {
        $release_number = $$rel{'release_number'};
    }
  }

  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= qq(<p><strong>Release $release_number</strong></p>
<h3>$news_cat_name</h3>
<h4>$title</h4>
<p>$content</p>
<p class="center">* * * * *</p>
<p><strong>Priority: $priority</strong></p>
<p>This item will be included in the news for:</p>
$species_list
);

  $html .= $panel->form( 'preview_item' )->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;

}

sub preview_item_form {
                                                                                
  my ($panel, $object) = @_;
  my $script = $object->script;
  my $species = $object->species;

  my $form = EnsEMBL::Web::Form->new( 'preview_item', "/$species/$script", 'post' );
  
  my %item = %{${$object->items}[0]};
  $form->add_element( 'type' => 'Hidden', 'name' => 'update', 'value' => 'yes');
  $form->add_element( 'type' => 'Hidden', 'name' => 'news_item_id', 'value' => $item{'news_item_id'});
  $form->add_element( 'type' => 'Hidden', 'name' => 'release_id', 'value' => $item{'release_id'});
  $form->add_element( 'type' => 'Hidden', 'name' => 'title', 'value' => $item{'title'});
  $form->add_element( 'type' => 'Hidden', 'name' => 'content', 'value' => $item{'content'});
  $form->add_element( 'type' => 'Hidden', 'name' => 'news_cat_id', 'value' => $item{'news_cat_id'});
  $form->add_element( 'type' => 'Hidden', 'name' => 'news_cat_name', 'value' => $item{'news_cat_name'});
  $form->add_element( 'type' => 'Hidden', 'name' => 'priority', 'value' => $item{'priority'});
  foreach my $sp (@{$item{'species'}}) {
    $form->add_element( 'type' => 'Hidden', 'name' => 'species', 'value' => $sp);
  }
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Edit');
  $form->add_element( 'type' => 'Submit', 'name' => 'submit', 'value' => 'Save Changes');
  return $form ;
}

1;
