package EnsEMBL::Web::Configuration::News;

use strict;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::Wizard::News;

our @ISA = qw( EnsEMBL::Web::Configuration );

#-----------------------------------------------------------------------

## Function to configure newsview

## This is a two-step view giving the user access to previous
## news items, by species, release, topic, etc.

sub newsview {
  my $self   = shift;
warn "Parameter ".$self->{object}->param('error');
  if (my $panel = $self->new_panel ('Image',
        'code'    => "info$self->{flag}",
        'object'  => $self->{object}) 
    ) {
    # this is a two-step view, so we need 2 separate sections
    if ($self->{object}->param('error') eq 'not_present') {
        $panel->{'caption'} = 'Not Present';
        $panel->add_components(qw(
                no_data     EnsEMBL::Web::Component::News::no_data
            ));
    }
    elsif ($self->{'object'}->param('submit') || $self->{'object'}->param('rel')) {
        # Step 2 - user has chosen a data range
        $panel->add_components(qw(show_news EnsEMBL::Web::Component::News::show_news));
    }
    else {
        # Step 1 - initial page display
        $panel->{'caption'} = 'Select News to View';
        $panel->add_components(qw(select_news EnsEMBL::Web::Component::News::select_news));
        $panel->add_form( $self->{page}, qw(select_news  EnsEMBL::Web::Component::News::select_news_form) );
    }
    $self->{page}->content->add_panel($panel);
  }
}

#-----------------------------------------------------------------------

sub context_menu {
    my $self = shift;
    my $species  = $self->{object}->species;
    my $flag     = "";
    $self->{page}->menu->add_block( $flag, 'bulleted', "News Archive" );

    $self->{page}->menu->add_entry( $flag, 'text' => "Select news to view",
                                  'href' => "/$species/newsview" );
    ## link back to previous release
    my $present = $SiteDefs::VERSION;
    my $current = $present;
    my $past = 0;
    if ($self->{object}->param('rel') < $present) { 
      $current = $self->{object}->param('rel');
      $past = 1;
    }
    my $previous = $current - 1;
    $self->{page}->menu->add_entry( $flag, 
                          'text' => "<< Release $previous",
                          'href' => "/$species/newsview?rel=$previous" );
    ## extra link forward if user has gone back to earlier news
    if ($past) {
      my $next = $current + 1;
      $self->{page}->menu->add_entry( $flag, 
                          'text' => ">> Release $next",
                          'href' => "/$species/newsview?rel=$next" );
      if ($current < ($present - 1)) {
        $self->{page}->menu->add_entry( $flag, 
                          'text' => "Current Release News",
                          'href' => "/$species/newsview?rel=$present" );
      }
    }
}

#---------------------------------------------------------------------------

sub news_add {
  my $self   = shift;
  my $object = $self->{'object'};
                                                                                
  ## the "add news" wizard uses 3 nodes: enter record, preview record,
  ## and save data
  my $wizard = EnsEMBL::Web::Wizard::News->new($object);
  $wizard->add_nodes([qw(enter preview save)]);
  $wizard->default_node('enter');
                                                                                
  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['enter'=>'preview'],
          ['enter'=>'save'],
          ['preview'=>'save'],
  ]);
                                                                                
  $self->add_wizard($wizard);
  $self->wizard_panel('Add a Current News Item');
}

sub news_edit {
  my $self   = shift;
  my $object = $self->{'object'};
                                                                                
  ## the "edit news" wizard uses 4 nodes: select record, enter record, 
  ## preview record, and save data
  my $wizard = EnsEMBL::Web::Wizard::News->new($object);
  $wizard->add_nodes([qw(select enter preview save)]);
  $wizard->default_node('select');
                                                                                
  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['select'=>'enter'],
          ['enter'=>'preview'],
          ['enter'=>'save'],
          ['preview'=>'save'],
  ]);
                                                                                
  $self->add_wizard($wizard);
  $self->wizard_panel('Edit a Current News Item');
}

sub news_add_old {
  my $self   = shift;
  my $object = $self->{'object'};
                                                                                
  ## the "add news" wizard uses 4 nodes: select release, enter record,
  ## preview record, and save data
  my $wizard = EnsEMBL::Web::Wizard::News->new($object);
  $wizard->add_nodes([qw(which_rel enter preview save)]);
  $wizard->default_node('which_rel');
                                                                                
  ## chain the nodes together 
  $wizard->add_outgoing_edges([
          ['which_rel'=>'enter'],
          ['enter'=>'preview'],
          ['enter'=>'save'],
          ['preview'=>'save'],
  ]);
                                                                                
  $self->add_wizard($wizard);
  $self->wizard_panel('Add an Item to the News Archive');
}

sub news_edit_old {
  my $self   = shift;
  my $object = $self->{'object'};
                                                                                
  ## the "edit news" wizard uses 5 nodes: select release, select record, 
  ## enter record, preview record, and save data
  my $wizard = EnsEMBL::Web::Wizard::News->new($object);
  $wizard->add_nodes([qw(which_rel select enter preview save)]);
  $wizard->default_node('which_rel');
                                                                                
  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['which_rel'=>'select'],
          ['select'=>'enter'],
          ['enter'=>'preview'],
          ['enter'=>'save'],
          ['preview'=>'save'],
  ]);
                                                                                
  $self->add_wizard($wizard);
  $self->wizard_panel('Edit an Item in the News Archive');
}

sub news_pub {
  my $self   = shift;
  my $object = $self->{'object'};
                                                                                
  ## the "publish news" wizard uses 4 nodes: select release, 
  ## select record + database, preview record, and save data
  my $wizard = EnsEMBL::Web::Wizard::News->new($object);
  $wizard->add_nodes([qw(which_rel pub_select pub_preview pub_save)]);
  $wizard->default_node('which_rel');
                                                                                
  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['which_rel'=>'pub_select'],
          ['pub_select'=>'pub_preview'],
          ['pub_preview'=>'pub_save'],
  ]);
                                                                                
  $self->add_wizard($wizard);
  $self->wizard_panel('Publish a story to a live database');
}

sub news_pub_multi {
  my $self   = shift;
  my $object = $self->{'object'};

  ## the "publish multi news" wizard uses 3 nodes: select release,
  ## select record(s) + database and save data
  my $wizard = EnsEMBL::Web::Wizard::News->new($object);
  $wizard->add_nodes([qw(which_rel multi_select pub_save)]);
  $wizard->default_node('which_rel');
                                                                                
  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['which_rel'=>'multi_select'],
          ['multi_select'=>'pub_save'],
  ]);
                                                                                
  $self->add_wizard($wizard);
  $self->wizard_panel('Publish multiple stories to a live database');
}

#---------------------------------------------------------------------------

sub editor_menu {
  my $self = shift;

  my $flag     = "current";
  $self->{page}->menu->add_block( $flag, 'bulleted', "Update Current News" );
  $self->{page}->menu->add_entry( $flag, 'text' => "Add Current News",
                                    'href' => "/Multi/add_news" );
  $self->{page}->menu->add_entry( $flag, 'text' => "Edit Current News",
                                    'href' => "/Multi/edit_news" );

  my $flag     = "archive";
  $self->{page}->menu->add_block( $flag, 'bulleted', "Update News Archive" );
  $self->{page}->menu->add_entry( $flag, 'text' => "Add News to Archive",
                                    'href' => "/Multi/add_old_news" );
  $self->{page}->menu->add_entry( $flag, 'text' => "Edit News Archive",
                                    'href' => "/Multi/edit_old_news" );

}

1;

__END__
                                                                                
=head1 EnsEMBL::Web::Configuration::News
                                                                                
=head2 SYNOPSIS

Children of this base class are called from the EnsEMBL::Web::Document::WebPage
object, according to parameters passed in from the controller script. There are
two ways of configuring the object:

1) A complex view (e.g. one that uses a form to collect additional user configuration settings) may need to explicitly call the configure method, thus:

  foreach my $object( @{$webpage->dataObjects} ) {
        $webpage->configure( $object, 'dataview', 'context_menu');
    }
    $webpage->render();
                                                                                
2) A simple view that does no additional data manipulation may be able to use a wrapper method, in which case it only needs to define its data object type, thus:
                                                                                
    EnsEMBL::Web::Document::WebPage::simple('Data');
                                                                                                                                             

=head2 DESCRIPTION
                                                                                
This class consists of methods for configuring views to display and/or manipulate news data. 

There are two types of method in a Configuration module, views and context menus, and every Configuration module should contain at least one example of each. 

'View' methods create the main content of a typical Ensembl dynamic page. Each creates one or more EnsEMBL::Web::Panel objects and adds one or more components to each panel.

'Context menu' methods create a menu of links to content related to that in the view. A generic menu method may be shared between similar views, or each view can have its own custom menu.

                                                                                
=head2 METHODS

All methods take an EnsEMBL::Web::Configuration::News object as their only argument (having already been instantiated by the WebPage object), and have no return value.
                                                                                
=head3 B<newsview>
                                                                                
Description: Allows the user to display a selection of news stories, filtered by release, species or category (topic).

=head3 B<context_menu>
                                                                                
Description: Very basic menu for newsview, with link back to filter page

=head3 B<newsdbview>
                                                                                
Description: Multi-page view controlling a db admin interface. Users can add and edit news stories.

=head3 B<editor_menu>
                                                                                
Description: Simple menu with options to jump to 'add' or 'edit' interfaces

=head2 BUGS AND LIMITATIONS
                                                                                
These views will need rewriting once the Wizard object has been developed.                                                                                    
=head2 AUTHOR
                                                                                
Anne Parker, Ensembl Web Team
Support enquiries: helpdesk\@ensembl.org
                                                                                
=head2 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html
                                                                                
=cut



