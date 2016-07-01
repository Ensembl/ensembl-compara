package EnsEMBL::Web::TextSequence::Layout::String;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Layout);

sub value_empty { return ''; }
sub value_pad { return ' ' x $_[1]; }
sub value_fmt { return sprintf($_[1],@{$_[2]}); }
sub value_cat { return join('',@{$_[1]}); }
sub value_length { return length $_[1]; }

1;
