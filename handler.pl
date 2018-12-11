use utf8;
use warnings;
use strict;
use Text::MeCab;
use Data::Dumper;

sub function {
    my ($payload) = @_;
    my $mecab = Text::MeCab->new();
    my @array;
    for (my $node = $mecab->parse($payload->{text}); $node; $node = $node->next) {
        my $word = {
        	surface => $node->surface,
        	feature => $node->feature,
        	cost => $node->cost,
        };
        push(@array, $word);
    }

    my $result = {
        result => \@array,
    };

    warn Dumper($result);

    return $result;
}

1;
