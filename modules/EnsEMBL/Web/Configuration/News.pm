package EnsEMBL::Web::Configuration::News;

use strict;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Configuration;

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
}

#-----------------------------------------------------------------------

## Function to configure newsdb view

## This is a "wizard" view that steps the user through a series of forms
## in order to add and edit news items

sub newsdbview {
    my $self   = shift;

    if (my $panel = $self->new_panel ('Image',
        'code'    => "info$self->{flag}",
        'object'  => $self->{object}) 
    ) {
        if ($self->{object}->param('submit') eq 'Preview') {
            $panel->{'caption'} = 'News Preview';    
            $panel->add_components(qw(
                preview_item     EnsEMBL::Web::Component::News::preview_item
            ));
            $self->add_form( $panel, qw(preview_item     EnsEMBL::Web::Component::News::preview_item_form) );
        }
        elsif ($self->{object}->param('submit') eq 'Edit') {
            $panel->{'caption'} = 'Edit this article';    
            $panel->add_components(qw(
                edit_item     EnsEMBL::Web::Component::News::edit_item
            ));
            $self->add_form( $panel, qw(edit_item     EnsEMBL::Web::Component::News::edit_item_form) );
        }
        elsif ($self->{object}->param('step2') && $self->{object}->param('action') ne 'add') { 
            $panel->{'caption'} = 'Edit a News article';    
            $panel->add_components(qw(
                select_item_only     EnsEMBL::Web::Component::News::select_item_only
            ));
            $self->add_form( $panel, qw(select_item  EnsEMBL::Web::Component::News::select_item_form) );
        }
        elsif ($self->{object}->param('release_id')) { 
            $panel->{'caption'} = 'Add a News article';    
            $panel->add_components(qw(
                add_item     EnsEMBL::Web::Component::News::add_item
            ));
            $self->add_form( $panel, qw(add_item     EnsEMBL::Web::Component::News::add_item_form) );
        }
        elsif ($self->{object}->param('submit') eq 'Add' || $self->{object}->param('action') eq 'add' ) { 
            $panel->{'caption'} = 'Add a News article';    
            $panel->add_components(qw(
                select_to_add     EnsEMBL::Web::Component::News::select_to_add
            ));
            $self->add_form( $panel, qw(select_release  EnsEMBL::Web::Component::News::select_release_form) );
        }
        else {
            $panel->{'caption'} = 'Update the News Database';    

            $panel->add_components(qw(
                select_to_edit     EnsEMBL::Web::Component::News::select_to_edit
            ));
            $self->add_form( $panel, qw(select_item     EnsEMBL::Web::Component::News::select_item_form) );
            $self->add_form( $panel, qw(select_release  EnsEMBL::Web::Component::News::select_release_form) );
        }
        $self->add_panel($panel);

    }
}

#---------------------------------------------------------------------------

sub editor_menu {
    my $self = shift;

    my $flag     = "";
    $self->{page}->menu->add_block( $flag, 'bulleted', "Update News Database" );

    $self->{page}->menu->add_entry( $flag, 'text' => "Add News",
                                    'href' => "/default/newsdbview?action=add" );
    $self->{page}->menu->add_entry( $flag, 'text' => "Edit News",
                                    'href' => "/default/newsdbview?action=edit" );

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



