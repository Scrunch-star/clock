module test_clock(
    input clk,
    input rst_n,
    input pill_pulse,
    input start,
    input stop,
    input bottle_ok,
    input [3:0] sw_target_ones,
    input [3:0] sw_target_tens,
    input sw_mode_limit,
    input sw_auto_move,
    output reg [6:0] seg_state,
    output [3:0] lg2_pill_ones,
    output [3:0] lg3_pill_tens,
    output [3:0] lg4_bot_ones,
    output [3:0] lg5_bot_tens,
    output [3:0] lg6_bot_hund,
    output alarm
);

    reg start_s, stop_s, pulse_s, bottle_s;
    reg start_d, stop_d, pulse_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_s <= 1'b0;
            stop_s <= 1'b0;
            pulse_s <= 1'b0;
            bottle_s <= 1'b0;
        end else begin
            start_s <= start;
            stop_s <= stop;
            pulse_s <= pill_pulse;
            bottle_s <= bottle_ok;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_d <= 1'b0;
            stop_d <= 1'b0;
            pulse_d <= 1'b0;
        end else begin
            start_d <= start_s;
            stop_d <= stop_s;
            pulse_d <= pulse_s;
        end
    end

    wire start_rise = start_s & ~start_d;
    wire stop_rise  = stop_s & ~stop_d;
    wire pulse_rise = pulse_s & ~pulse_d;

    reg [9:0] div_cnt;
    reg tick_1hz;
    reg blink;
    wire [9:0] div_max = sw_auto_move ? 10'd100 : 10'd1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt <= 10'd0;
            tick_1hz <= 1'b0;
            blink <= 1'b0;
        end else begin
            if (div_cnt == (div_max - 10'd1)) begin
                div_cnt <= 10'd0;
                tick_1hz <= 1'b1;
                blink <= ~blink;
            end else begin
                div_cnt <= div_cnt + 10'd1;
                tick_1hz <= 1'b0;
            end
        end
    end

    reg set_mode;
    reg [1:0] sel;
    reg run_en;

    reg [3:0] hour_tens, hour_ones;
    reg [3:0] min_tens, min_ones;
    reg [3:0] sec_tens, sec_ones;

    wire tick_en = run_en && tick_1hz && (!set_mode || sw_mode_limit);
    wire inc_hour_clk = set_mode && !sw_mode_limit && pulse_rise && (sel == 2'd0);
    wire inc_min_clk  = set_mode && !sw_mode_limit && pulse_rise && (sel == 2'd1);
    wire inc_sec_clk  = set_mode && !sw_mode_limit && pulse_rise && (sel == 2'd2);
    wire inc_hour_alarm = set_mode && sw_mode_limit && pulse_rise && (sel == 2'd0);
    wire inc_min_alarm  = set_mode && sw_mode_limit && pulse_rise && (sel == 2'd1);

    wire sec_ones_max = (sec_ones == 4'd9);
    wire sec_tens_max = (sec_tens == 4'd5);
    wire min_ones_max = (min_ones == 4'd9);
    wire min_tens_max = (min_tens == 4'd5);
    wire hour_ones_max = (hour_tens == 4'd2) ? (hour_ones == 4'd3) : (hour_ones == 4'd9);
    wire hour_is_23 = (hour_tens == 4'd2) && (hour_ones == 4'd3);

    wire en_sec = tick_en | inc_sec_clk;
    wire carry_sec_ones = en_sec & sec_ones_max;
    wire carry_sec = carry_sec_ones & sec_tens_max;
    wire carry_sec_tick = tick_en & sec_ones_max & sec_tens_max;

    wire en_min = carry_sec_tick | inc_min_clk;
    wire carry_min_ones = en_min & min_ones_max;
    wire carry_min_tick = carry_sec_tick & min_ones_max & min_tens_max;

    wire en_hour = carry_min_tick | inc_hour_clk;

    reg [3:0] alarm_hour_tens, alarm_hour_ones;
    reg [3:0] alarm_min_tens, alarm_min_ones;

    wire alarm_min_ones_max = (alarm_min_ones == 4'd9);
    wire alarm_min_tens_max = (alarm_min_tens == 4'd5);
    wire alarm_hour_ones_max = (alarm_hour_tens == 4'd2) ? (alarm_hour_ones == 4'd3) : (alarm_hour_ones == 4'd9);
    wire alarm_hour_is_23 = (alarm_hour_tens == 4'd2) && (alarm_hour_ones == 4'd3);

    wire alarm_carry_min_ones = inc_min_alarm & alarm_min_ones_max;
    wire alarm_en_hour = inc_hour_alarm;

    reg alarm_active;
    reg [5:0] alarm_ring_cnt;
    wire alarm_en = bottle_s;

    wire alarm_fire = alarm_en && !set_mode && tick_en &&
                      (sec_tens == 4'd0) && (sec_ones == 4'd0) &&
                      (min_tens == alarm_min_tens) && (min_ones == alarm_min_ones) &&
                      (hour_tens == alarm_hour_tens) && (hour_ones == alarm_hour_ones);

    reg chime_active;
    reg [1:0] chime_cnt;
    wire chime_fire = !set_mode && run_en && tick_1hz &&
                      (sec_tens == 4'd0) && (sec_ones == 4'd0) &&
                      (min_tens == 4'd0) && (min_ones == 4'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            set_mode <= 1'b0;
            sel <= 2'd0;
            run_en <= 1'b1;
            hour_tens <= 4'd0;
            hour_ones <= 4'd0;
            min_tens <= 4'd0;
            min_ones <= 4'd0;
            sec_tens <= 4'd0;
            sec_ones <= 4'd0;
            alarm_hour_tens <= 4'd0;
            alarm_hour_ones <= 4'd0;
            alarm_min_tens <= 4'd0;
            alarm_min_ones <= 4'd0;
            alarm_active <= 1'b0;
            alarm_ring_cnt <= 6'd0;
            chime_active <= 1'b0;
            chime_cnt <= 2'd0;
        end else begin
            if (start_rise && !set_mode) begin
                run_en <= ~run_en;
            end

            if (stop_rise) begin
                set_mode <= ~set_mode;
                sel <= 2'd0;
            end

            if (set_mode && start_rise) begin
                if (sw_mode_limit) begin
                    if (sel == 2'd1) sel <= 2'd0;
                    else sel <= sel + 2'd1;
                end else begin
                    if (sel == 2'd2) sel <= 2'd0;
                    else sel <= sel + 2'd1;
                end
            end

            if (en_sec) begin
                if (sec_ones_max) sec_ones <= 4'd0;
                else sec_ones <= sec_ones + 4'd1;
            end

            if (carry_sec_ones) begin
                if (sec_tens_max) sec_tens <= 4'd0;
                else sec_tens <= sec_tens + 4'd1;
            end

            if (en_min) begin
                if (min_ones_max) min_ones <= 4'd0;
                else min_ones <= min_ones + 4'd1;
            end

            if (carry_min_ones) begin
                if (min_tens_max) min_tens <= 4'd0;
                else min_tens <= min_tens + 4'd1;
            end

            if (en_hour) begin
                if (hour_is_23) begin
                    hour_tens <= 4'd0;
                    hour_ones <= 4'd0;
                end else if (hour_ones_max) begin
                    hour_ones <= 4'd0;
                    hour_tens <= hour_tens + 4'd1;
                end else begin
                    hour_ones <= hour_ones + 4'd1;
                end
            end

            if (inc_min_alarm) begin
                if (alarm_min_ones_max) alarm_min_ones <= 4'd0;
                else alarm_min_ones <= alarm_min_ones + 4'd1;
            end

            if (alarm_carry_min_ones) begin
                if (alarm_min_tens_max) alarm_min_tens <= 4'd0;
                else alarm_min_tens <= alarm_min_tens + 4'd1;
            end

            if (alarm_en_hour) begin
                if (alarm_hour_is_23) begin
                    alarm_hour_tens <= 4'd0;
                    alarm_hour_ones <= 4'd0;
                end else if (alarm_hour_ones_max) begin
                    alarm_hour_ones <= 4'd0;
                    alarm_hour_tens <= alarm_hour_tens + 4'd1;
                end else begin
                    alarm_hour_ones <= alarm_hour_ones + 4'd1;
                end
            end

            if (!alarm_en) begin
                alarm_active <= 1'b0;
                alarm_ring_cnt <= 6'd0;
            end else if (alarm_fire) begin
                alarm_active <= 1'b1;
                alarm_ring_cnt <= 6'd0;
            end else if (alarm_active) begin
                if (start_rise || stop_rise) begin
                    alarm_active <= 1'b0;
                    alarm_ring_cnt <= 6'd0;
                end else if (tick_en) begin
                    if (alarm_ring_cnt == 6'd29) begin
                        alarm_active <= 1'b0;
                        alarm_ring_cnt <= 6'd0;
                    end else begin
                        alarm_ring_cnt <= alarm_ring_cnt + 6'd1;
                    end
                end
            end

            if (set_mode) begin
                chime_active <= 1'b0;
                chime_cnt <= 2'd0;
            end else if (alarm_active || alarm_fire) begin
                chime_active <= 1'b0;
                chime_cnt <= 2'd0;
            end else if (chime_fire) begin
                chime_active <= 1'b1;
                chime_cnt <= 2'd0;
            end else if (chime_active) begin
                if (start_rise || stop_rise) begin
                    chime_active <= 1'b0;
                    chime_cnt <= 2'd0;
                end else if (tick_1hz) begin
                    if (chime_cnt == 2'd1) begin
                        chime_active <= 1'b0;
                        chime_cnt <= 2'd0;
                    end else begin
                        chime_cnt <= chime_cnt + 2'd1;
                    end
                end
            end
        end
    end

    wire edit_alarm = set_mode && sw_mode_limit;
    wire [3:0] disp_hour_tens = edit_alarm ? alarm_hour_tens : hour_tens;
    wire [3:0] disp_hour_ones = edit_alarm ? alarm_hour_ones : hour_ones;
    wire [3:0] disp_min_tens  = edit_alarm ? alarm_min_tens  : min_tens;
    wire [3:0] disp_min_ones  = edit_alarm ? alarm_min_ones  : min_ones;
    wire [3:0] disp_sec_tens  = edit_alarm ? 4'd0 : sec_tens;
    wire [3:0] disp_sec_ones  = edit_alarm ? 4'd0 : sec_ones;

    always @(*) begin
        if (set_mode && !sw_mode_limit && (sel == 2'd2) && !blink) begin
            seg_state = 7'b0000000;
        end else begin
            case (disp_sec_ones)
                4'd0: seg_state = 7'b1111110;
                4'd1: seg_state = 7'b0110000;
                4'd2: seg_state = 7'b1101101;
                4'd3: seg_state = 7'b1111001;
                4'd4: seg_state = 7'b0110011;
                4'd5: seg_state = 7'b1011011;
                4'd6: seg_state = 7'b1011111;
                4'd7: seg_state = 7'b1110000;
                4'd8: seg_state = 7'b1111111;
                4'd9: seg_state = 7'b1111011;
                default: seg_state = 7'b0000000;
            endcase
        end
    end

    wire blink_off = set_mode && !blink;
    wire sel_clk_hour = set_mode && !sw_mode_limit && (sel == 2'd0);
    wire sel_clk_min  = set_mode && !sw_mode_limit && (sel == 2'd1);
    wire sel_clk_sec  = set_mode && !sw_mode_limit && (sel == 2'd2);
    wire sel_alarm_hour = set_mode && sw_mode_limit && (sel == 2'd0);
    wire sel_alarm_min  = set_mode && sw_mode_limit && (sel == 2'd1);

    wire [3:0] blank_bcd = 4'hf;

    assign lg2_pill_ones = (blink_off && sel_clk_sec) ? blank_bcd : disp_sec_tens;
    assign lg3_pill_tens = (blink_off && (sel_clk_min || sel_alarm_min)) ? blank_bcd : disp_min_ones;
    assign lg4_bot_ones  = (blink_off && (sel_clk_min || sel_alarm_min)) ? blank_bcd : disp_min_tens;
    assign lg5_bot_tens  = (blink_off && (sel_clk_hour || sel_alarm_hour)) ? blank_bcd : disp_hour_ones;
    assign lg6_bot_hund  = (blink_off && (sel_clk_hour || sel_alarm_hour)) ? blank_bcd : disp_hour_tens;

    assign alarm = alarm_active ? clk : (chime_active ? clk : (set_mode ? blink : 1'b0));

endmodule
