"""The gallery order that tools/portal_images.py sets on the mod portal."""

from tools import portal_images as pi


def test_the_first_image_leads_and_the_current_ones_stay():
    assert pi.gallery_order(["a", "b"], ["c", "d"], "c") == ["c", "a", "b", "d"]


def test_an_image_that_is_already_there_is_not_doubled():
    assert pi.gallery_order(["a", "c"], ["c", "d"], "d") == ["d", "a", "c"]


def test_a_new_image_that_comes_twice_is_listed_once():
    assert pi.gallery_order([], ["c", "c", "d"], "c") == ["c", "d"]
