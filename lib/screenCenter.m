function p = screenCenter(w, h)
    % From: https://github.com/cafarm/appbox
    s = get(0, 'ScreenSize');
    sw = s(3);
    sh = s(4);
    x = (sw - w) / 2;
    y = (sh - h) / 2;
    p = [x y w h];
end