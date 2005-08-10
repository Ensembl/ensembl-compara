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
  my @item_values;
  foreach my $item (@items) {
    my $code = $$item{'news_item_id'};
    my $species_count = scalar(@{$$item{'species'}});
    my $sp_name;
    if ($species_count > 1) {
        $sp_name = 'multi-species';
    }
    else {
        my @sp_list = @{$$item{'species'}};
        $sp_name = $sp_list[0]{'species_name'};
    }
    
    my $name = 'Rel '.$$item{'release'}.' - '.$$item{'title'}." ($sp_name)";
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
  $form->add_element( 'type' => 'Submit', 'name' => 'edit', 'value' => 'Edit');
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
 
  my $form = EnsEMBL::Web::Form->new( 'select_item', "/default/$script", 'post' );
  
  $form->add_element( 'type' => 'SubHeader', 'value' => 'Select a previous release');
  $form->add_element(
    'type'     => 'DropDown',
    'select'   => 'select',
    'required' => 'yes',
    'name'     => 'release',
    'label'    => 'Release',
    'values'   => \@rel_values,
  );

  $form->add_element( 'type' => 'Submit', 'name' => 'select', 'value' => 'Next');
  return $form ;
}

sub preview_item {
                                                                                
  my ($panel, $object) = @_;
                                                                                
  my $html = qq(<div class="formpanel" style="width:80%">);

  my $title = $object->param('title');
  my $content = $object->param('content');
  my $release = $object->param('release');
  my $news_cat_name = $object->param('news_cat_name');
  my @species = split(',', $object->param('species'));
  my $priority = $object->param('priority');

  my $species_list = '<ul>';
  foreach my $sp (@species) {
    my $sp_name = $$sp{'species_name'};
    $species_list .= "<li>$sp_name</li>";
  }
  $species_list .= '</ul>';

  $html .= qq(<p><strong>Release $release</strong></p>
<h3>$news_cat_name</h3>
<h4>$title</h4>
<p>$content</p>
<p class="center">* * * * *</p>
<p><strong>Priority: $priority</strong></p>
<p>This item will be included in the news for:</p>
$species_list
);

  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub item_form {
                                                                                
  my ($form, $object) = @_;
  my ($id, $name, $date);
                                                                                
  # set default values for form
  my ($title, $content, $release_id);
  my $release = $object->species_defs->ENSEMBL_VERSION;
  my $news_cat_id = 2; # data
  my @species = [{'species_id'=>'1', 'species_name'=>'Homo_sapiens'}];
  my $priority = 0;

  if (scalar(@{$object->items}) == 1) { # have selected a single item but not opted to save changes yet
    my %item = %{${$object->items}[0]};
    $title = $item{'title'};
    $content = $item{'content'};
    $release_id = $item{'release_id'};
    $release = $item{'release'};
    $news_cat_id = $item{'news_cat_id'};
    @species = @{$item{'species'}};
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
  my @all_species = @{$object->all_spp};
  my @spp_values;
  foreach my $sp (@all_species) {
    $id = $$sp{'species_id'};
    $name = $$sp{'species_name'};
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
    'name'     => 'release',
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
    'value'    => \@species,
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
  $form->add_element( 'type' => 'Submit', 'name' => 'preview', 'value' => 'Preview');
  $form->add_element( 'type' => 'Submit', 'name' => 'save', 'value' => 'Save Changes');
  return $form ;
}

1;
