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

}

#-----------------------------------------------------------------------

sub context_menu {

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
        elsif ($self->{object}->param('submit') eq 'Add' || $self->{object}->param('action') eq 'add' ) { 
            $panel->{'caption'} = 'Add a News article';    
            $panel->add_components(qw(
                add_item     EnsEMBL::Web::Component::News::add_item
            ));
            $self->add_form( $panel, qw(add_item     EnsEMBL::Web::Component::News::add_item_form) );
        }
        else {
            $panel->{'caption'} = 'Update the News Database';    

            $panel->add_components(qw(
                select_news     EnsEMBL::Web::Component::News::select_news
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
